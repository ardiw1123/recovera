import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/constants/api_constants.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/network/auth_interceptor.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';

/// Adapter mock in-memory untuk menyimulasikan skenario backend secara deterministik
class MockHttpClientAdapter implements HttpClientAdapter {
  MockHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody jsonResponse(
    Map<String, dynamic> data, {
    int statusCode = 200,
    Map<String, List<String>>? headers,
  }) {
    final responseBytes = utf8.encode(jsonEncode(data));
    return ResponseBody.fromBytes(
      responseBytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?headers,
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Penyimpanan Token Terenkripsi (Android KeyStore & Secure Storage)', () {
    test('SecureTokenStorage mengonfigurasi Android KeyStore options', () {
      final androidMap = SecureTokenStorage.androidOptions.toMap();
      expect(androidMap['encryptedSharedPreferences'], 'true');

      final iosMap = SecureTokenStorage.iosOptions.toMap();
      expect(iosMap['accessibility'], contains('first_unlock'));
    });

    test('InMemoryTokenStorage menyimpan, memperbarui, dan menghapus kredensial', () async {
      final storage = InMemoryTokenStorage();

      expect(await storage.hasValidToken(), isFalse);
      expect(await storage.getTokens(), isNull);

      const tokens = AuthTokens(
        accessToken: 'access-token-123',
        refreshToken: 'refresh-token-456',
        userId: 42,
        role: 'seller',
        name: 'PT Mitra Sejati',
      );

      await storage.saveTokens(tokens);

      expect(await storage.hasValidToken(), isTrue);
      expect(await storage.getAccessToken(), 'access-token-123');
      expect(await storage.getRefreshToken(), 'refresh-token-456');

      final saved = await storage.getTokens();
      expect(saved, isNotNull);
      expect(saved?.accessToken, 'access-token-123');
      expect(saved?.refreshToken, 'refresh-token-456');
      expect(saved?.userId, 42);
      expect(saved?.role, 'seller');

      // Update access token & refresh token rotasi
      await storage.saveAccessToken('new-access-token');
      await storage.saveRefreshToken('new-refresh-token');
      expect(await storage.getAccessToken(), 'new-access-token');
      expect(await storage.getRefreshToken(), 'new-refresh-token');

      // Hapus token
      await storage.clearTokens();
      expect(await storage.hasValidToken(), isFalse);
      expect(await storage.getTokens(), isNull);
    });
  });

  group('Dio AuthInterceptor & Request Lifecycle', () {
    late InMemoryTokenStorage tokenStorage;

    setUp(() {
      tokenStorage = InMemoryTokenStorage();
    });

    test('Secara otomatis menyuntikkan header Authorization Bearer pada request privat', () async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'valid-secret-token',
          refreshToken: 'valid-refresh-token',
        ),
      );

      RequestOptions? interceptedOptions;

      final adapter = MockHttpClientAdapter((options) async {
        interceptedOptions = options;
        return MockHttpClientAdapter.jsonResponse({
          'success': true,
          'data': {'status': 'ok'},
        });
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        tokenStorage: tokenStorage,
        adapter: adapter,
      );

      final response = await apiClient.get<Map<String, dynamic>>('/profile');

      expect(response.statusCode, 200);
      expect(
        interceptedOptions?.headers['Authorization'],
        'Bearer valid-secret-token',
      );
    });

    test('Endpoint publik tidak disuntikkan Bearer token', () async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'valid-secret-token',
          refreshToken: 'valid-refresh-token',
        ),
      );

      RequestOptions? loginOptions;

      final adapter = MockHttpClientAdapter((options) async {
        loginOptions = options;
        return MockHttpClientAdapter.jsonResponse({
          'success': true,
          'data': {'access_token': 'new-tok', 'refresh_token': 'new-ref'},
        });
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        tokenStorage: tokenStorage,
        adapter: adapter,
      );

      await apiClient.post<Map<String, dynamic>>(
        ApiConstants.loginEndpoint,
        data: {'email': 'test@test.com', 'password': 'pass'},
      );

      expect(loginOptions?.headers.containsKey('Authorization'), isFalse);
    });

    test('HTTP 401 memicu silent refresh ke /auth/refresh dan retry transparan', () async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'expired-access-token',
          refreshToken: 'valid-refresh-token',
        ),
      );

      int privateEndpointCallCount = 0;
      int refreshEndpointCallCount = 0;
      final List<String?> sentAuthHeaders = [];

      late MockHttpClientAdapter adapter;
      adapter = MockHttpClientAdapter((options) async {
        if (options.path.contains('/auth/refresh')) {
          refreshEndpointCallCount++;
          final dynamic rawData = options.data;
          final Map<String, dynamic> body = rawData is Map<String, dynamic>
              ? rawData
              : (rawData is String ? jsonDecode(rawData) as Map<String, dynamic> : {});
          expect(body['refresh_token'], 'valid-refresh-token');

          return MockHttpClientAdapter.jsonResponse({
            'success': true,
            'data': {
              'access_token': 'refreshed-access-token-999',
              'refresh_token': 'rotated-refresh-token-888',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 1,
              'role': 'seller',
              'name': 'Budi',
            },
          });
        }

        if (options.path.contains('/listings/my')) {
          privateEndpointCallCount++;
          sentAuthHeaders.add(options.headers['Authorization'] as String?);

          // Panggilan pertama gagal 401 karena access token kedaluwarsa
          if (privateEndpointCallCount == 1) {
            return MockHttpClientAdapter.jsonResponse(
              {
                'success': false,
                'error': {
                  'code': 'TOKEN_EXPIRED',
                  'message': 'Access token has expired',
                },
              },
              statusCode: 401,
            );
          }

          // Panggilan kedua (retry) harus berhasil
          return MockHttpClientAdapter.jsonResponse({
            'success': true,
            'data': [{'id': 1, 'title': 'Apel Malang'}],
          });
        }

        return MockHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      final refreshDio = Dio()..httpClientAdapter = adapter;

      final interceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshDio: refreshDio,
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(interceptor);

      // Jalankan request privat yang mengalami 401 pertama kali
      final response = await dio.get<Map<String, dynamic>>(
        '/listings/my',
        options: Options(extra: {'_adapter': adapter}),
      );

      // Verifikasi request berhasil diselesaikan transparan bagi pemanggil
      expect(response.statusCode, 200);
      expect(response.data?['success'], isTrue);
      expect(privateEndpointCallCount, 2);
      expect(refreshEndpointCallCount, 1);

      // Verifikasi token pada header: panggilan awal menggunakan token lama, retry menggunakan token baru
      expect(sentAuthHeaders[0], 'Bearer expired-access-token');
      expect(sentAuthHeaders[1], 'Bearer refreshed-access-token-999');

      // Verifikasi token baru & rotasi refresh token tersimpan di storage
      final currentTokens = await tokenStorage.getTokens();
      expect(currentTokens?.accessToken, 'refreshed-access-token-999');
      expect(currentTokens?.refreshToken, 'rotated-refresh-token-888');
    });

    test('Multiple concurrent 401 requests mengoordinasikan satu pemanggilan refresh (retry queue tanpa race condition)', () async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'expired-token',
          refreshToken: 'valid-refresh-token',
        ),
      );

      int refreshCallCount = 0;
      final Map<String, int> callCounts = {};

      late MockHttpClientAdapter adapter;
      adapter = MockHttpClientAdapter((options) async {
        if (options.path.contains('/auth/refresh')) {
          refreshCallCount++;
          // Beri jeda kecil untuk menyimulasikan latensi jaringan refresh
          await Future.delayed(const Duration(milliseconds: 50));
          return MockHttpClientAdapter.jsonResponse({
            'success': true,
            'data': {
              'access_token': 'new-shared-access-token',
              'refresh_token': 'new-rotated-refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 10,
              'role': 'buyer',
              'name': 'Siti',
            },
          });
        }

        final path = options.path;
        callCounts[path] = (callCounts[path] ?? 0) + 1;

        if (callCounts[path] == 1) {
          // Pertama kali semua return 401
          return MockHttpClientAdapter.jsonResponse(
            {'success': false, 'error': {'code': 'UNAUTHORIZED'}},
            statusCode: 401,
          );
        }

        // Retry kedua berhasil
        return MockHttpClientAdapter.jsonResponse({
          'success': true,
          'data': {'endpoint': path},
        });
      });

      final refreshDio = Dio()..httpClientAdapter = adapter;

      final interceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshDio: refreshDio,
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(interceptor);

      // Jalankan 3 request privat secara bersamaan
      final futures = [
        dio.get<Map<String, dynamic>>('/orders', options: Options(extra: {'_adapter': adapter})),
        dio.get<Map<String, dynamic>>('/notifications', options: Options(extra: {'_adapter': adapter})),
        dio.get<Map<String, dynamic>>('/profile', options: Options(extra: {'_adapter': adapter})),
      ];

      final results = await Future.wait(futures);

      // Seluruh 3 request harus berhasil
      for (final res in results) {
        expect(res.statusCode, 200);
        expect(res.data?['success'], isTrue);
      }

      // Pastikan HANYA SATU kali pemanggilan ke /auth/refresh
      expect(refreshCallCount, 1);

      // Pastikan token tersimpan diperbarui
      expect(await tokenStorage.getAccessToken(), 'new-shared-access-token');
      expect(await tokenStorage.getRefreshToken(), 'new-rotated-refresh-token');
    });

    test('Refresh token kedaluwarsa menghapus sesi dan memicu notifikasi sesi berakhir', () async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'expired-access-token',
          refreshToken: 'expired-refresh-token',
        ),
      );

      String? sessionExpiredNotice;

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path.contains('/auth/refresh')) {
          // Backend mengembalikan 401 EXPIRED_REFRESH_TOKEN sesuai kontrak David
          return MockHttpClientAdapter.jsonResponse(
            {
              'success': false,
              'error': {
                'code': ApiConstants.errorExpiredRefreshToken,
                'message': 'Refresh token has expired',
              },
            },
            statusCode: 401,
          );
        }

        // Request privat awal 401
        return MockHttpClientAdapter.jsonResponse(
          {'success': false, 'error': {'code': 'UNAUTHORIZED'}},
          statusCode: 401,
        );
      });

      final refreshDio = Dio()..httpClientAdapter = adapter;

      final interceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshDio: refreshDio,
        onSessionExpired: (msg) {
          sessionExpiredNotice = msg;
        },
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(interceptor);

      // Request privat harus gagal DioException karena refresh token sudah tidak sah
      await expectLater(
        dio.get<Map<String, dynamic>>(
          '/profile',
          options: Options(extra: {'_adapter': adapter}),
        ),
        throwsA(isA<DioException>()),
      );

      // Verifikasi sesi dihapus dari tokenStorage
      expect(await tokenStorage.hasValidToken(), isFalse);
      expect(await tokenStorage.getTokens(), isNull);

      // Verifikasi pesan sesi kedaluwarsa diterima
      expect(sessionExpiredNotice, isNotNull);
      expect(
        sessionExpiredNotice,
        contains('kedaluwarsa'),
      );
    });

    test('Kesalahan jaringan / 5xx pada refresh bersifat sementara dan tidak menghapus kredensial', () async {
      await tokenStorage.saveTokens(
        const AuthTokens(
          accessToken: 'old-access-token',
          refreshToken: 'valid-refresh-token',
        ),
      );

      bool sessionExpiredTriggered = false;

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path.contains('/auth/refresh')) {
          // Simulasi server 503 Service Unavailable sementara
          return MockHttpClientAdapter.jsonResponse(
            {'success': false, 'error': {'code': 'SERVICE_UNAVAILABLE'}},
            statusCode: 503,
          );
        }

        return MockHttpClientAdapter.jsonResponse(
          {'success': false, 'error': {'code': 'UNAUTHORIZED'}},
          statusCode: 401,
        );
      });

      final refreshDio = Dio()..httpClientAdapter = adapter;

      final interceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshDio: refreshDio,
        onSessionExpired: (_) => sessionExpiredTriggered = true,
      );

      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(interceptor);

      await expectLater(
        dio.get<Map<String, dynamic>>(
          '/profile',
          options: Options(extra: {'_adapter': adapter}),
        ),
        throwsA(isA<DioException>()),
      );

      await Future.delayed(const Duration(milliseconds: 20));

      // Token TIDAK boleh dihapus untuk transient network failure
      expect(await tokenStorage.getRefreshToken(), 'valid-refresh-token');
      expect(sessionExpiredTriggered, isFalse);
    });
  });

  group('AuthRepository Integration', () {
    test('login menyimpan kredensial dan logout menghapus kredensial', () async {
      final storage = InMemoryTokenStorage();

      final adapter = MockHttpClientAdapter((options) async {
        if (options.path.contains('/auth/login')) {
          return MockHttpClientAdapter.jsonResponse({
            'success': true,
            'data': {
              'access_token': 'login-access-token',
              'refresh_token': 'login-refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 7,
              'role': 'buyer',
              'name': 'Warung Berkah',
            },
          });
        }

        if (options.path.contains('/auth/logout')) {
          return MockHttpClientAdapter.jsonResponse({
            'success': true,
            'data': {'message': 'Successfully logged out'},
          });
        }

        return MockHttpClientAdapter.jsonResponse({}, statusCode: 404);
      });

      final client = ApiClient(
        baseUrl: 'http://test.local',
        tokenStorage: storage,
        adapter: adapter,
      );

      final repo = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: storage,
      );

      expect(repo.isAuthenticated, isFalse);

      final tokens = await repo.login(
        email: 'warung@berkah.com',
        password: 'password123',
      );

      expect(tokens.accessToken, 'login-access-token');
      expect(repo.isAuthenticated, isTrue);
      expect(await storage.getAccessToken(), 'login-access-token');

      // Logout
      await repo.logout();
      expect(repo.isAuthenticated, isFalse);
      expect(await storage.getTokens(), isNull);
    });
  });
}
