import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recovera/core/constants/api_constants.dart';
import 'package:recovera/core/navigation/app_navigator.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/network/auth_interceptor.dart';
import 'package:recovera/core/storage/token_storage.dart';

/// Adapter mock in-memory deterministik (tanpa jaringan nyata).
class QaMockAdapter implements HttpClientAdapter {
  QaMockAdapter(this.handler);

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

  static ResponseBody json(
    Map<String, dynamic> data, {
    int statusCode = 200,
  }) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(data)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> envelopeError(String code, String message) => {
      'success': false,
      'error': {'code': code, 'message': message},
    };

Map<String, dynamic> envelopeTokens({
  required String access,
  required String refresh,
}) =>
    {
      'success': true,
      'data': {
        'access_token': access,
        'refresh_token': refresh,
        'token_type': 'bearer',
        'expires_in': 3600,
        'user_id': 5,
        'role': 'seller',
        'name': 'QA Fixture',
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Penyimpanan kredensial aman
  // ───────────────────────────────────────────────────────────────────────────
  group('QA-01 Penyimpanan kredensial aman (Android KeyStore)', () {
    test('SecureTokenStorage memakai encryptedSharedPreferences + iOS Keychain',
        () {
      expect(
        SecureTokenStorage.androidOptions.toMap()['encryptedSharedPreferences'],
        'true',
      );
      expect(
        SecureTokenStorage.iosOptions.toMap()['accessibility'],
        contains('first_unlock'),
      );
    });

    test('kunci penyimpanan token bersifat spesifik per aplikasi', () {
      final keys = {
        ApiConstants.keyAccessToken,
        ApiConstants.keyRefreshToken,
        ApiConstants.keyTokenType,
        ApiConstants.keyExpiresIn,
        ApiConstants.keyUserId,
        ApiConstants.keyUserRole,
        ApiConstants.keyUserName,
      };
      expect(keys.length, 7);
      for (final k in keys) {
        expect(k, startsWith('recovera_'));
      }
    });

    test('rotasi token memperbarui nilai lama dan clearTokens menghapus semuanya',
        () async {
      final storage = InMemoryTokenStorage();
      expect(await storage.hasValidToken(), isFalse);

      await storage.saveTokens(
        const AuthTokens(
          accessToken: 'a1',
          refreshToken: 'r1',
          userId: 9,
          role: 'buyer',
          name: 'QA',
        ),
      );
      expect(await storage.hasValidToken(), isTrue);

      await storage.saveAccessToken('a2');
      expect(await storage.getAccessToken(), 'a2');
      expect(await storage.getRefreshToken(), 'r1',
          reason: 'rotasi access token tidak boleh menghapus refresh token');

      await storage.saveRefreshToken('r2');
      expect(await storage.getRefreshToken(), 'r2');

      await storage.clearTokens();
      expect(await storage.getTokens(), isNull);
      expect(await storage.hasValidToken(), isFalse);
    });

    test('AuthTokens fromJson/toJson round-trip konsisten', () {
      final parsed = AuthTokens.fromJson({
        'access_token': 'acc',
        'refresh_token': 'ref',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user_id': '77',
        'role': 'seller',
        'name': 'Toko',
      });
      expect(parsed.userId, 77);
      expect(AuthTokens.fromJson(parsed.toJson()), equals(parsed));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Autentikasi request privat
  // ───────────────────────────────────────────────────────────────────────────
  group('QA-02 Autentikasi request privat', () {
    late InMemoryTokenStorage storage;
    setUp(() => storage = InMemoryTokenStorage());

    test('Bearer dari secure storage dipakai dan menimpa header pemanggil',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'real-token', refreshToken: 'r'),
      );

      RequestOptions? seen;
      final api = ApiClient(
        baseUrl: 'http://unit.test',
        tokenStorage: storage,
        adapter: QaMockAdapter((o) async {
          seen = o;
          return QaMockAdapter.json({'success': true, 'data': {}});
        }),
      );

      await api.get<Map<String, dynamic>>(
        '/orders',
        options: Options(
          headers: {'Authorization': 'Bearer stale-caller-token'},
        ),
      );

      expect(seen?.headers['Authorization'], 'Bearer real-token');
    });

    test('endpoint publik tidak diberi Bearer', () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'real-token', refreshToken: 'r'),
      );

      final captured = <String, RequestOptions>{};
      final api = ApiClient(
        baseUrl: 'http://unit.test',
        tokenStorage: storage,
        adapter: QaMockAdapter((o) async {
          captured[o.path] = o;
          return QaMockAdapter.json({'success': true, 'data': {}});
        }),
      );

      await api.post<Map<String, dynamic>>(ApiConstants.loginEndpoint,
          data: {'email': 'a@b.c', 'password': 'x'});
      await api.post<Map<String, dynamic>>(ApiConstants.registerEndpoint,
          data: {'email': 'a@b.c'});
      await api.post<Map<String, dynamic>>(ApiConstants.refreshEndpoint,
          data: {'refresh_token': 'r'});

      expect(captured.length, 3);
      for (final entry in captured.entries) {
        expect(entry.value.headers.containsKey('Authorization'), isFalse,
            reason: '${entry.key} seharusnya publik tanpa Bearer');
      }
    });

    test('endpoint privat dengan extra noAuth tidak diberi Bearer', () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'real-token', refreshToken: 'r'),
      );

      RequestOptions? seen;
      final api = ApiClient(
        baseUrl: 'http://unit.test',
        tokenStorage: storage,
        adapter: QaMockAdapter((o) async {
          seen = o;
          return QaMockAdapter.json({'success': true, 'data': {}});
        }),
      );

      await api.get<Map<String, dynamic>>(
        '/orders',
        options: Options(extra: {AuthInterceptor.noAuthExtraKey: true}),
      );

      expect(seen?.headers.containsKey('Authorization'), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Pemulihan 401 & antrean retry
  // ───────────────────────────────────────────────────────────────────────────
  group('QA-03 Pemulihan 401 & antrean retry', () {
    late InMemoryTokenStorage storage;
    setUp(() => storage = InMemoryTokenStorage());

    test(
        'lima 401 bersamaan → tepat satu refresh, semua retry sukses, tanpa duplikasi',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );

      final counts = <String, int>{};
      final refreshBodies = <String?>[];
      final retryAuthHeaders = <String?>[];

      final adapter = QaMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          counts['__refresh'] = (counts['__refresh'] ?? 0) + 1;
          final raw = o.data;
          final body = raw is Map<String, dynamic>
              ? raw
              : jsonDecode(raw.toString()) as Map<String, dynamic>;
          refreshBodies.add(body['refresh_token'] as String?);
          await Future.delayed(const Duration(milliseconds: 60));
          return QaMockAdapter.json(
            envelopeTokens(access: 'fresh-access', refresh: 'fresh-refresh'),
          );
        }
        counts[o.path] = (counts[o.path] ?? 0) + 1;
        if (counts[o.path] == 1) {
          return QaMockAdapter.json(
            envelopeError('UNAUTHORIZED', 'expired'),
            statusCode: 401,
          );
        }
        retryAuthHeaders.add(o.headers['Authorization'] as String?);
        return QaMockAdapter.json({'success': true, 'data': {'path': o.path}});
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
        ));

      final paths = [
        '/orders',
        '/profile',
        '/notifications',
        '/listings/my',
        '/stok',
      ];
      final results = await Future.wait([
        for (final p in paths)
          dio.get<Map<String, dynamic>>(p,
              options: Options(extra: {'_adapter': adapter})),
      ]);

      for (final r in results) {
        expect(r.statusCode, 200);
        expect(r.data?['success'], isTrue);
      }

      expect(counts['__refresh'], 1, reason: 'refresh harus single-flight');
      expect(refreshBodies, ['rt-1'],
          reason: 'refresh memakai refresh token tersimpan');
      for (final p in paths) {
        expect(counts[p], 2, reason: '$p harus tepat satu kali retry');
      }
      expect(retryAuthHeaders.length, 5);
      for (final h in retryAuthHeaders) {
        expect(h, 'Bearer fresh-access');
      }

      final tokens = await storage.getTokens();
      expect(tokens?.accessToken, 'fresh-access');
      expect(tokens?.refreshToken, 'fresh-refresh');
      expect(tokens?.role, 'seller',
          reason: 'metadata user ikut tersimpan saat rotasi');
    });

    test(
        'request baru saat refresh berjalan memakai token baru tanpa 401 tambahan',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );

      final refreshStarted = Completer<void>();
      final counts = <String, int>{};

      final adapter = QaMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          counts['__refresh'] = (counts['__refresh'] ?? 0) + 1;
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          await Future.delayed(const Duration(milliseconds: 120));
          return QaMockAdapter.json(
            envelopeTokens(access: 'fresh-access', refresh: 'fresh-refresh'),
          );
        }
        counts[o.path] = (counts[o.path] ?? 0) + 1;
        // Backend menolak khusus access token yang sudah kedaluwarsa
        if (o.headers['Authorization'] == 'Bearer expired') {
          return QaMockAdapter.json(
            envelopeError('UNAUTHORIZED', 'expired'),
            statusCode: 401,
          );
        }
        return QaMockAdapter.json({'success': true, 'data': {}});
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
        ));

      final first = dio.get<Map<String, dynamic>>('/orders',
          options: Options(extra: {'_adapter': adapter}));
      await refreshStarted.future;

      final during = dio.get<Map<String, dynamic>>('/notifications',
          options: Options(extra: {'_adapter': adapter}));

      final results = await Future.wait([first, during]);

      for (final r in results) {
        expect(r.statusCode, 200);
      }
      expect(counts['__refresh'], 1);
      expect(counts['/orders'], 2, reason: '401 lalu retry');
      expect(counts['/notifications'], 1,
          reason: 'request yang menunggu refresh tidak boleh kena 401 lagi');
    });

    test('POST non-idempotent diulang tepat satu kali dengan body & token baru',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );

      final bodies = <dynamic>[];
      final authHeaders = <String?>[];
      int refreshCount = 0;

      final adapter = QaMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          refreshCount++;
          return QaMockAdapter.json(
            envelopeTokens(access: 'fresh-access', refresh: 'fresh-refresh'),
          );
        }
        bodies.add(o.data);
        authHeaders.add(o.headers['Authorization'] as String?);
        if (bodies.length == 1) {
          return QaMockAdapter.json(
            envelopeError('UNAUTHORIZED', 'expired'),
            statusCode: 401,
          );
        }
        return QaMockAdapter.json({'success': true, 'data': {'id': 123}});
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
        ));

      final res = await dio.post<Map<String, dynamic>>(
        '/orders',
        data: {'listing_id': 1, 'qty': 2},
        options: Options(extra: {'_adapter': adapter}),
      );

      expect(res.statusCode, 200);
      expect(bodies.length, 2,
          reason: 'POST tidak boleh terkirim lebih dari dua kali');
      expect(bodies[0], {'listing_id': 1, 'qty': 2});
      expect(bodies[1], {'listing_id': 1, 'qty': 2});
      expect(authHeaders[0], 'Bearer expired');
      expect(authHeaders[1], 'Bearer fresh-access');
      expect(refreshCount, 1);
    });

    test('retry yang kembali 401 berhenti tanpa loop pemulihan', () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );

      int privateHits = 0;
      int refreshCount = 0;

      final adapter = QaMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          refreshCount++;
          return QaMockAdapter.json(
            envelopeTokens(access: 'fresh-access', refresh: 'fresh-refresh'),
          );
        }
        privateHits++;
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'still rejected'),
          statusCode: 401,
        );
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
        ));

      await expectLater(
        dio.get<Map<String, dynamic>>('/orders',
            options: Options(extra: {'_adapter': adapter})),
        throwsA(isA<DioException>()),
      );

      expect(privateHits, 2,
          reason: 'satu panggilan awal + satu retry, tidak lebih');
      expect(refreshCount, 1);
    });

    test('siklus refresh direset sehingga 401 berikutnya memicu refresh baru',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired-1', refreshToken: 'rt-1'),
      );

      int refreshCount = 0;
      final seenRefreshTokens = <String?>[];
      // Simulasi access token yang selalu kedaluwarsa sekali per "masa berlaku"
      bool accessExpired = true;

      final adapter = QaMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          refreshCount++;
          final raw = o.data;
          final body = raw is Map<String, dynamic>
              ? raw
              : jsonDecode(raw.toString()) as Map<String, dynamic>;
          seenRefreshTokens.add(body['refresh_token'] as String?);
          return QaMockAdapter.json(
            envelopeTokens(
              access: 'access-$refreshCount',
              refresh: 'rt-${refreshCount + 1}',
            ),
          );
        }
        if (accessExpired) {
          accessExpired = false;
          return QaMockAdapter.json(
            envelopeError('UNAUTHORIZED', 'expired'),
            statusCode: 401,
          );
        }
        return QaMockAdapter.json({'success': true, 'data': {}});
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
        ));

      await dio.get<Map<String, dynamic>>('/orders',
          options: Options(extra: {'_adapter': adapter}));
      expect(refreshCount, 1);

      // Token berikutnya juga kedaluwarsa → 401 baru harus memicu refresh baru
      accessExpired = true;
      await dio.get<Map<String, dynamic>>('/orders',
          options: Options(extra: {'_adapter': adapter}));
      expect(refreshCount, 2, reason: 'completer harus direset antar siklus');
      expect(seenRefreshTokens, ['rt-1', 'rt-2'],
          reason: 'refresh harus memakai refresh token hasil rotasi terbaru');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Sesi berakhir
  // ───────────────────────────────────────────────────────────────────────────
  group('QA-04 Penanganan sesi berakhir', () {
    late InMemoryTokenStorage storage;
    setUp(() => storage = InMemoryTokenStorage());

    ({Dio dio, List<String> notices}) harness(
      Future<ResponseBody> Function(RequestOptions o) handler, {
      String access = 'expired',
      String? refresh = 'rt-1',
    }) {
      final notices = <String>[];
      final adapter = QaMockAdapter(handler);
      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
          onSessionExpired: notices.add,
        ));
      return (dio: dio, notices: notices);
    }

    test(
        'EXPIRED_REFRESH_TOKEN → sesi dibersihkan, pesan kedaluwarsa, satu notifikasi',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );
      final h = harness((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          return QaMockAdapter.json(
            envelopeError(
              ApiConstants.errorExpiredRefreshToken,
              'Refresh token has expired',
            ),
            statusCode: 401,
          );
        }
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'expired'),
          statusCode: 401,
        );
      });

      await expectLater(
        h.dio.get<Map<String, dynamic>>('/profile'),
        throwsA(isA<DioException>()),
      );

      expect(await storage.getTokens(), isNull);
      expect(await storage.hasValidToken(), isFalse);
      expect(h.notices.length, 1,
          reason: 'satu peristiwa sesi berakhir = satu notifikasi');
      expect(h.notices.single, contains('kedaluwarsa'));
    });

    test(
        'INVALID_REFRESH_TOKEN memberi pesan berbeda dan tetap membersihkan sesi',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );
      final h = harness((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          return QaMockAdapter.json(
            envelopeError(
              ApiConstants.errorInvalidRefreshToken,
              'Refresh token is invalid or revoked',
            ),
            statusCode: 401,
          );
        }
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'expired'),
          statusCode: 401,
        );
      });

      await expectLater(
        h.dio.get<Map<String, dynamic>>('/profile'),
        throwsA(isA<DioException>()),
      );

      expect(await storage.getTokens(), isNull);
      expect(h.notices.single, contains('tidak lagi valid'));
    });

    test('refresh membalas 200 dengan success:false → sesi dibersihkan',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );
      final h = harness((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          return QaMockAdapter.json(
            envelopeError('SESSION_REVOKED', 'Session revoked'),
          );
        }
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'expired'),
          statusCode: 401,
        );
      });

      await expectLater(
        h.dio.get<Map<String, dynamic>>('/profile'),
        throwsA(isA<DioException>()),
      );

      expect(await storage.getTokens(), isNull);
      expect(h.notices.length, 1);
    });

    test('refresh 500 (transient) → kredensial dipertahankan tanpa notifikasi',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );
      final h = harness((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          return QaMockAdapter.json(
            envelopeError('INTERNAL_SERVER_ERROR', 'boom'),
            statusCode: 500,
          );
        }
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'expired'),
          statusCode: 401,
        );
      });

      await expectLater(
        h.dio.get<Map<String, dynamic>>('/profile'),
        throwsA(isA<DioException>()),
      );

      expect(await storage.getRefreshToken(), 'rt-1');
      expect(await storage.getAccessToken(), 'expired');
      expect(h.notices, isEmpty);
    });

    test('koneksi putus (transient) → kredensial dipertahankan tanpa notifikasi',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );
      final h = harness((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          throw DioException.connectionError(
            requestOptions: o,
            reason: 'socket closed',
          );
        }
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'expired'),
          statusCode: 401,
        );
      });

      await expectLater(
        h.dio.get<Map<String, dynamic>>('/profile'),
        throwsA(isA<DioException>()),
      );

      expect(await storage.getRefreshToken(), 'rt-1');
      expect(h.notices, isEmpty);
    });

    test('refresh token hilang → sesi dibersihkan tanpa panggilan jaringan',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: ''),
      );

      int refreshNetworkHits = 0;
      final h = harness((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          refreshNetworkHits++;
        }
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'expired'),
          statusCode: 401,
        );
      });

      await expectLater(
        h.dio.get<Map<String, dynamic>>('/profile'),
        throwsA(isA<DioException>()),
      );

      expect(refreshNetworkHits, 0);
      expect(await storage.getTokens(), isNull);
      expect(h.notices.single, ApiConstants.sessionExpiredMessage);
    });

    test('permintaan langsung ke /auth/refresh yang 401 → sesi dibersihkan',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );
      final notices = <String>[];
      final adapter = QaMockAdapter((o) async {
        return QaMockAdapter.json(
          envelopeError(ApiConstants.errorExpiredRefreshToken, 'expired'),
          statusCode: 401,
        );
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
          onSessionExpired: notices.add,
        ));

      await expectLater(
        dio.post<Map<String, dynamic>>(
          ApiConstants.refreshEndpoint,
          data: {'refresh_token': 'rt-1'},
        ),
        throwsA(isA<DioException>()),
      );

      expect(notices.length, 1);
      expect(await storage.getTokens(), isNull);
    });

    test('beberapa 401 bersamaan saat refresh gagal tetap satu notifikasi',
        () async {
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );
      final notices = <String>[];
      final adapter = QaMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          await Future.delayed(const Duration(milliseconds: 40));
          return QaMockAdapter.json(
            envelopeError(ApiConstants.errorExpiredRefreshToken, 'expired'),
            statusCode: 401,
          );
        }
        return QaMockAdapter.json(
          envelopeError('UNAUTHORIZED', 'expired'),
          statusCode: 401,
        );
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
          onSessionExpired: notices.add,
        ));

      final outcomes = await Future.wait([
        for (final p in ['/orders', '/profile', '/notifications'])
          dio
              .get<Map<String, dynamic>>(p,
                  options: Options(extra: {'_adapter': adapter}))
              .then((_) => 'ok', onError: (_) => 'error'),
      ]);

      expect(outcomes.every((o) => o == 'error'), isTrue);
      expect(notices.length, 1,
          reason: 'dedup: satu peristiwa sesi berakhir, satu notifikasi');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5. UX sesi berakhir (navigasi + pesan)
  // ───────────────────────────────────────────────────────────────────────────
  group('QA-05 UX sesi berakhir', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    testWidgets(
        'handleSessionExpired membuang rute privat, membuka Login, pesan tampil sekali',
        (tester) async {
      LoginProbe.buildCount = 0;
      LoginProbe.lastArguments = null;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppNavigator.navigatorKey,
          scaffoldMessengerKey: AppNavigator.scaffoldMessengerKey,
          initialRoute: '/home',
          routes: {
            '/home': (_) => const Scaffold(body: Text('PRIVATE HOME')),
            '/login': (_) => const LoginProbe(),
          },
        ),
      );

      expect(find.text('PRIVATE HOME'), findsOneWidget);

      AppNavigator.handleSessionExpired(message: 'Sesi QA berakhir.');
      await tester.pumpAndSettle();

      expect(find.text('PRIVATE HOME'), findsNothing,
          reason: 'layar privat harus dibongkar total');
      expect(find.text('LOGIN SCREEN'), findsOneWidget);
      expect(LoginProbe.buildCount, 1);
      expect(LoginProbe.lastArguments?['session_expired'], isTrue);
      expect(LoginProbe.lastArguments?['message'], 'Sesi QA berakhir.');
      expect(find.text('Sesi QA berakhir.'), findsOneWidget,
          reason: 'pesan sesi berakhir harus terlihat pengguna');

      AppNavigator.handleSessionExpired(message: 'Sesi QA berakhir.');
      await tester.pump();
      expect(LoginProbe.buildCount, 1, reason: 'navigasi hanya sekali');

      await tester.pump(const Duration(seconds: 3));
    });
  });
}

class LoginProbe extends StatefulWidget {
  const LoginProbe({super.key});

  static int buildCount = 0;
  static Map<String, dynamic>? lastArguments;

  @override
  State<LoginProbe> createState() => _LoginProbeState();
}

class _LoginProbeState extends State<LoginProbe> {
  @override
  void initState() {
    super.initState();
    LoginProbe.buildCount++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (LoginProbe.lastArguments != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      LoginProbe.lastArguments = args;
    } else if (args is Map) {
      LoginProbe.lastArguments = args.cast<String, dynamic>();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('LOGIN SCREEN')));
  }
}
