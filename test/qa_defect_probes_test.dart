// QA defect probes — sengaja menguji perilaku yang SEHARUSNYA benar.
// Kegagalan di berkas ini adalah bukti defect, bukan kegagalan harness.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/constants/api_constants.dart';
import 'package:recovera/core/network/auth_interceptor.dart';
import 'package:recovera/core/storage/token_storage.dart';

class ProbeMockAdapter implements HttpClientAdapter {
  ProbeMockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}

  static ResponseBody json(Map<String, dynamic> data, {int statusCode = 200}) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(data)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QA DEFECT PROBES', () {
    test(
        'DEF-01 silent refresh harus mengikuti base URL klien (ApiClient/updateBaseUrl)',
        () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );

      Uri? refreshUri;
      final adapter = ProbeMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          refreshUri = o.uri;
          return ProbeMockAdapter.json({
            'success': true,
            'data': {
              'access_token': 'fresh',
              'refresh_token': 'rt-2',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 1,
              'role': 'seller',
              'name': 'X',
            },
          });
        }
        if (o.headers['Authorization'] == 'Bearer expired') {
          return ProbeMockAdapter.json({
            'success': false,
            'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
          }, statusCode: 401);
        }
        return ProbeMockAdapter.json({'success': true, 'data': {}});
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://tenant.example'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
        ));

      await dio.get<Map<String, dynamic>>('/orders',
          options: Options(extra: {'_adapter': adapter}));

      expect(refreshUri, isNotNull, reason: 'refresh harus benar-benar dipanggil');
      expect(refreshUri!.host, 'tenant.example',
          reason: 'refresh harus menuju host yang sama dengan request privat '
              '(ApiClient(baseUrl:) / updateBaseUrl tidak boleh diabaikan)');
      expect(refreshUri!.path, ApiConstants.refreshEndpoint);
    });

    test(
        'DEF-02 build release Android harus punya permission INTERNET agar request privat dapat dikirim',
        () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason: 'AndroidManifest utama (dipakai build release) tidak '
            'mendeklarasikan INTERNET — seluruh request privat/Bearer gagal '
            'di perangkat pada build rilis.',
      );
    });

    test('DEF-03 sesi berakhir hanya boleh dinotifikasi sekali per sesi',
        () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );

      final notices = <String>[];
      final adapter = ProbeMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          return ProbeMockAdapter.json({
            'success': false,
            'error': {
              'code': ApiConstants.errorExpiredRefreshToken,
              'message': 'Refresh token has expired',
            },
          }, statusCode: 401);
        }
        return ProbeMockAdapter.json({
          'success': false,
          'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
        }, statusCode: 401);
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
          onSessionExpired: notices.add,
        ));

      await expectLater(
        dio.get<Map<String, dynamic>>('/orders',
            options: Options(extra: {'_adapter': adapter})),
        throwsA(isA<DioException>()),
      );
      expect(notices.length, 1);

      // Request privat yang datang setelah sesi dibersihkan (mis. request
      // tertunda / background refresh) tidak boleh menotifikasi ulang.
      await expectLater(
        dio.get<Map<String, dynamic>>('/orders',
            options: Options(extra: {'_adapter': adapter})),
        throwsA(isA<DioException>()),
      );

      expect(notices.length, 1,
          reason: 'satu peristiwa sesi berakhir seharusnya hanya menotifikasi '
              'sekali, bukan sekali per request gagal');
    });

    test('DEF-04 bukti: retry memakai ulang instance FormData yang sama', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(
        const AuthTokens(accessToken: 'expired', refreshToken: 'rt-1'),
      );

      final sentData = <dynamic>[];
      final adapter = ProbeMockAdapter((o) async {
        if (o.path.contains(ApiConstants.refreshEndpoint)) {
          return ProbeMockAdapter.json({
            'success': true,
            'data': {
              'access_token': 'fresh',
              'refresh_token': 'rt-2',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user_id': 1,
              'role': 'seller',
              'name': 'X',
            },
          });
        }
        sentData.add(o.data);
        if (o.headers['Authorization'] == 'Bearer expired') {
          return ProbeMockAdapter.json({
            'success': false,
            'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
          }, statusCode: 401);
        }
        return ProbeMockAdapter.json({'success': true, 'data': {}});
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(
          tokenStorage: storage,
          refreshDio: Dio()..httpClientAdapter = adapter,
        ));

      final form = FormData.fromMap({
        'caption': 'listing',
        'photo': MultipartFile.fromBytes([1, 2, 3], filename: 'p.png'),
      });

      Object? thrown;
      try {
        await dio.post<Map<String, dynamic>>('/listings',
            data: form, options: Options(extra: {'_adapter': adapter}));
      } catch (e) {
        thrown = e;
      }

      expect(
        thrown,
        isNull,
        reason: 'retry unggahan multipart harus transparan setelah refresh; '
            'instance FormData dipakai ulang sehingga Dio melempar '
            '"The FormData has already been finalized"',
      );
      expect(sentData.length, 2, reason: 'satu kiriman awal + satu retry');
    });
  });
}
