import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/services/push_notification_service.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';

class _PushMockAdapter implements HttpClientAdapter {
  _PushMockAdapter(this.handler);

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

  static ResponseBody json(Map<String, dynamic> body, {int statusCode = 200}) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService token & /devices registration', () {
    test(
      'still calls getToken() and posts fcm_token even when register() throws',
      () async {
        final postedPayloads = <Map<String, dynamic>>[];
        final storage = InMemoryTokenStorage();
        await storage.saveAccessToken('jwt-user-159');

        final client = ApiClient(
          baseUrl: 'http://test.api',
          tokenStorage: storage,
          adapter: _PushMockAdapter((options) async {
            if (options.path == '/devices') {
              postedPayloads.add(Map<String, dynamic>.from(options.data as Map));
              return _PushMockAdapter.json({
                'success': true,
                'data': {'message': 'Device registered successfully'},
              });
            }
            return _PushMockAdapter.json({'success': false}, statusCode: 404);
          }),
        );

        final service = PushNotificationService.forTesting(
          apiClient: client,
          isAuthenticated: () => true,
          isAuthLoading: () => false,
          currentUserId: () => 159,
          registerFcm: () async => throw Exception('FIS_AUTH_ERROR'),
          getFcmToken: () async => 'real-fcm-token-159',
          onTokenRefresh: const Stream.empty(),
          onRegistered: const Stream.empty(),
        );

        await service.init();

        expect(service.currentFcmToken, 'real-fcm-token-159');
        expect(postedPayloads, [
          {'fcm_token': 'real-fcm-token-159'},
        ]);
      },
    );

    test(
      'does not let onRegistered FID overwrite valid fcm_token in /devices payload',
      () async {
        final postedPayloads = <Map<String, dynamic>>[];
        final registeredController = StreamController<String>.broadcast();
        final storage = InMemoryTokenStorage();
        await storage.saveAccessToken('jwt-user-163');

        final client = ApiClient(
          baseUrl: 'http://test.api',
          tokenStorage: storage,
          adapter: _PushMockAdapter((options) async {
            if (options.path == '/devices') {
              postedPayloads.add(Map<String, dynamic>.from(options.data as Map));
              return _PushMockAdapter.json({'success': true, 'data': {}});
            }
            return _PushMockAdapter.json({'success': false}, statusCode: 404);
          }),
        );

        final service = PushNotificationService.forTesting(
          apiClient: client,
          isAuthenticated: () => true,
          isAuthLoading: () => false,
          currentUserId: () => 163,
          registerFcm: () async {},
          getFcmToken: () async => 'real-fcm-token-163',
          onTokenRefresh: const Stream.empty(),
          onRegistered: registeredController.stream,
        );

        await service.init();
        registeredController.add('firebase-installation-id-xyz');
        await Future<void>.delayed(Duration.zero);

        expect(service.currentFcmToken, 'real-fcm-token-163');
        expect(service.currentFid, 'firebase-installation-id-xyz');
        expect(
          postedPayloads.any((p) => p['fcm_token'] == 'firebase-installation-id-xyz'),
          isFalse,
        );
        expect(postedPayloads.first, {'fcm_token': 'real-fcm-token-163'});

        await registeredController.close();
      },
    );

    test(
      'falls back to fid payload when only onRegistered FID is available',
      () async {
        final postedPayloads = <Map<String, dynamic>>[];
        final registeredController = StreamController<String>.broadcast();
        final storage = InMemoryTokenStorage();
        await storage.saveAccessToken('jwt-fid-only');

        final client = ApiClient(
          baseUrl: 'http://test.api',
          tokenStorage: storage,
          adapter: _PushMockAdapter((options) async {
            if (options.path == '/devices') {
              postedPayloads.add(Map<String, dynamic>.from(options.data as Map));
              return _PushMockAdapter.json({'success': true, 'data': {}});
            }
            return _PushMockAdapter.json({'success': false}, statusCode: 404);
          }),
        );

        final service = PushNotificationService.forTesting(
          apiClient: client,
          isAuthenticated: () => true,
          isAuthLoading: () => false,
          currentUserId: () => 200,
          registerFcm: () async => registeredController.add('only-fid-200'),
          getFcmToken: () async => null,
          onTokenRefresh: const Stream.empty(),
          onRegistered: registeredController.stream,
        );

        await service.init();
        await Future<void>.delayed(Duration.zero);

        expect(postedPayloads, [
          {'fid': 'only-fid-200'},
        ]);
        await registeredController.close();
      },
    );

    test(
      'fetches token lazily on login when startup token was null and re-registers on user switch',
      () async {
        final postedLog = <String>[];
        var authed = false;
        var currentUid = 163;
        var fcmCalls = 0;

        final storage = InMemoryTokenStorage();
        final client = ApiClient(
          baseUrl: 'http://test.api',
          tokenStorage: storage,
          adapter: _PushMockAdapter((options) async {
            if (options.path == '/devices') {
              postedLog.add('user=$currentUid:${jsonEncode(options.data)}');
              return _PushMockAdapter.json({'success': true, 'data': {}});
            }
            return _PushMockAdapter.json({'success': false}, statusCode: 404);
          }),
        );

        final service = PushNotificationService.forTesting(
          apiClient: client,
          isAuthenticated: () => authed,
          isAuthLoading: () => false,
          currentUserId: () => authed ? currentUid : null,
          registerFcm: () async {},
          getFcmToken: () async {
            fcmCalls++;
            // First startup check returns null (e.g. offline); login retry succeeds.
            return fcmCalls == 1 ? null : 'late-fcm-token';
          },
          onTokenRefresh: const Stream.empty(),
          onRegistered: const Stream.empty(),
        );

        await service.init();
        expect(postedLog, isEmpty);

        // User 163 logs in -> fetches token lazily and registers
        authed = true;
        currentUid = 163;
        await storage.saveAccessToken('jwt-163');
        await service.registerCurrentInstallation();

        // Duplicate call for same user+token should be deduplicated
        await service.registerCurrentInstallation();

        // Logout then login as user 159 -> must re-register for user 159
        authed = false;
        await service.registerCurrentInstallation();
        authed = true;
        currentUid = 159;
        await storage.saveAccessToken('jwt-159');
        await service.registerCurrentInstallation();

        expect(postedLog, [
          'user=163:{"fcm_token":"late-fcm-token"}',
          'user=159:{"fcm_token":"late-fcm-token"}',
        ]);
      },
    );

    test(
      'retries registration when connectivity returns after an offline login',
      () async {
        final connectivityController = StreamController<bool>.broadcast();
        final postedPayloads = <Map<String, dynamic>>[];
        var online = false;

        final storage = InMemoryTokenStorage();
        await storage.saveAccessToken('jwt-offline');

        final client = ApiClient(
          baseUrl: 'http://test.api',
          tokenStorage: storage,
          adapter: _PushMockAdapter((options) async {
            if (options.path == '/devices') {
              if (!online) {
                throw DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                );
              }
              postedPayloads.add(Map<String, dynamic>.from(options.data as Map));
              return _PushMockAdapter.json({'success': true, 'data': {}});
            }
            return _PushMockAdapter.json({'success': false}, statusCode: 404);
          }),
        );

        final service = PushNotificationService.forTesting(
          apiClient: client,
          isAuthenticated: () => true,
          isAuthLoading: () => false,
          currentUserId: () => 159,
          registerFcm: () async {},
          getFcmToken: () async => 'fcm-reconnect-159',
          onTokenRefresh: const Stream.empty(),
          onRegistered: const Stream.empty(),
          onConnectivityChanged: connectivityController.stream,
        );

        await service.init();
        expect(postedPayloads, isEmpty);

        online = true;
        connectivityController.add(true);
        await Future<void>.delayed(Duration.zero);

        expect(postedPayloads, [
          {'fcm_token': 'fcm-reconnect-159'},
        ]);
        await connectivityController.close();
      },
    );

    test(
      'background handler skips local duplicate when notification block is present and shows data-only payload',
      () async {
        final shown = <Map<String, dynamic>>[];
        Future<void> fakeShow({
          required int id,
          required String title,
          required String body,
          Map<String, dynamic>? data,
        }) async {
          shown.add({'id': id, 'title': title, 'body': body, 'data': data});
        }

        // Standard FCM message with notification block -> Android already shows tray notification.
        const trayMessage = RemoteMessage(
          notification: RemoteNotification(title: 'Pesanan Baru', body: 'Ada order'),
          data: {'type': 'new_order', 'order_id': '150'},
        );
        await handleBackgroundRemoteMessage(trayMessage, showNotification: fakeShow);
        expect(shown, isEmpty);

        // Data-only message -> handler shows local notification.
        const dataOnlyMessage = RemoteMessage(
          data: {
            'title': 'Stok Baru',
            'body': 'Cocok untuk bisnis Anda',
            'type': 'new_listing',
            'listing_id': '42',
          },
        );
        await handleBackgroundRemoteMessage(dataOnlyMessage, showNotification: fakeShow);
        expect(shown.length, 1);
        expect(shown.first['title'], 'Stok Baru');
        expect(shown.first['body'], 'Cocok untuk bisnis Anda');
      },
    );

    test(
      'AuthRepository.logout forwards registered device identifier to /auth/logout',
      () async {
        Map<String, dynamic>? logoutPayload;
        final storage = InMemoryTokenStorage();
        await storage.saveTokens(
          const AuthTokens(
            accessToken: 'acc-1',
            refreshToken: 'ref-1',
            userId: 163,
            role: 'buyer',
            name: 'Buyer',
          ),
        );

        final client = ApiClient(
          baseUrl: 'http://test.api',
          tokenStorage: storage,
          adapter: _PushMockAdapter((options) async {
            if (options.path == '/auth/logout') {
              logoutPayload = Map<String, dynamic>.from(options.data as Map);
              return _PushMockAdapter.json({
                'success': true,
                'data': {'message': 'Logged out'},
              });
            }
            return _PushMockAdapter.json({'success': false}, statusCode: 404);
          }),
        );

        final repo = AuthRepository(
          authApiService: AuthApiService(client: client),
          tokenStorage: storage,
        );
        await repo.init();
        repo.beforeLogoutDeviceProvider = () => {'fcm_token': 'tok-logout-163'};

        await repo.logout();

        expect(logoutPayload, {
          'refresh_token': 'ref-1',
          'fcm_token': 'tok-logout-163',
        });
      },
    );
  });
}
