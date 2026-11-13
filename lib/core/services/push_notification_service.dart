import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/navigation/app_navigator.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import 'network_connectivity_service.dart';

const _recoveraChannelId = 'recovera_notifications';
const _recoveraChannelName = 'Notifikasi Recovera';
const _recoveraChannelDescription =
    'Pembaruan pesanan dan penawaran Recovera';

NotificationDetails _buildRecoveraNotificationDetails() {
  return const NotificationDetails(
    android: AndroidNotificationDetails(
      _recoveraChannelId,
      _recoveraChannelName,
      channelDescription: _recoveraChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await handleBackgroundRemoteMessage(
    message,
    showNotification: ({
      required int id,
      required String title,
      required String body,
      Map<String, dynamic>? data,
    }) async {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await localNotifications.initialize(
        settings: const InitializationSettings(android: android),
      );
      await localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _buildRecoveraNotificationDetails(),
        payload: data != null ? jsonEncode(data) : null,
      );
    },
  );
}

/// Handles background/terminated push messages without duplicating FCM tray alerts.
///
/// Android automatically displays notifications when `message.notification != null`.
/// Only data-only payloads with `title` and `body` need a manual local notification.
Future<void> handleBackgroundRemoteMessage(
  RemoteMessage message, {
  required Future<void> Function({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) showNotification,
}) async {
  if (message.notification != null) {
    return;
  }

  final title = message.data['title']?.toString().trim() ?? '';
  final body = message.data['body']?.toString().trim() ?? '';
  if (title.isEmpty || body.isEmpty) {
    return;
  }

  final notificationKey = message.messageId ?? '${title}_$body';
  await showNotification(
    id: notificationKey.hashCode,
    title: title,
    body: body,
    data: message.data,
  );
}

class PushNotificationService {
  PushNotificationService._()
      : _isTesting = false,
        _apiClientOverride = null,
        _getFcmTokenOverride = null,
        _registerFcmOverride = null,
        _onTokenRefreshOverride = null,
        _onRegisteredOverride = null,
        _isAuthenticatedOverride = null,
        _isAuthLoadingOverride = null,
        _currentUserIdOverride = null,
        _onConnectivityChangedOverride = null;

  @visibleForTesting
  PushNotificationService.forTesting({
    ApiClient? apiClient,
    Future<String?> Function()? getFcmToken,
    Future<void> Function()? registerFcm,
    Stream<String>? onTokenRefresh,
    Stream<String>? onRegistered,
    bool Function()? isAuthenticated,
    bool Function()? isAuthLoading,
    int? Function()? currentUserId,
    Stream<bool>? onConnectivityChanged,
  })  : _isTesting = true,
        _apiClientOverride = apiClient == null ? null : (() => apiClient),
        _getFcmTokenOverride = getFcmToken,
        _registerFcmOverride = registerFcm,
        _onTokenRefreshOverride = onTokenRefresh,
        _onRegisteredOverride = onRegistered,
        _isAuthenticatedOverride = isAuthenticated,
        _isAuthLoadingOverride = isAuthLoading,
        _currentUserIdOverride = currentUserId,
        _onConnectivityChangedOverride = onConnectivityChanged;

  static final instance = PushNotificationService._();

  final bool _isTesting;
  final ApiClient Function()? _apiClientOverride;
  final Future<String?> Function()? _getFcmTokenOverride;
  final Future<void> Function()? _registerFcmOverride;
  final Stream<String>? _onTokenRefreshOverride;
  final Stream<String>? _onRegisteredOverride;
  final bool Function()? _isAuthenticatedOverride;
  final bool Function()? _isAuthLoadingOverride;
  final int? Function()? _currentUserIdOverride;
  final Stream<bool>? _onConnectivityChangedOverride;

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _started = false;
  String? _fcmToken;
  String? _fid;
  String? _lastRegisteredKey;
  Future<void>? _registrationInFlight;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<String>? _onRegisteredSub;
  StreamSubscription<bool>? _connectivitySub;

  ApiClient get _apiClient =>
      _apiClientOverride?.call() ?? AuthRepository.instance.authApiService.client;
  bool get _isAuthenticated =>
      _isAuthenticatedOverride?.call() ?? AuthRepository.instance.isAuthenticated;
  bool get _isAuthLoading =>
      _isAuthLoadingOverride?.call() ?? AuthRepository.instance.isLoading;
  int? get _currentUserId =>
      _currentUserIdOverride?.call() ??
      AuthRepository.instance.currentTokens?.userId ??
      AuthRepository.instance.currentUserProfile?.id;

  String? get currentFcmToken => _fcmToken;
  String? get currentFid => _fid;

  /// Returns the preferred device identifier payload (`fcm_token` before `fid`).
  Map<String, String?>? get currentDevicePayload {
    final token = _fcmToken;
    if (token != null && token.isNotEmpty) {
      return {'fcm_token': token};
    }
    final fid = _fid;
    if (fid != null && fid.isNotEmpty) {
      return {'fid': fid};
    }
    return null;
  }

  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      if (!_isTesting) {
        await Firebase.initializeApp();
        _messaging = FirebaseMessaging.instance;
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        const android = AndroidInitializationSettings('@mipmap/ic_launcher');
        await _localNotifications.initialize(
          settings: const InitializationSettings(android: android),
          onDidReceiveNotificationResponse: (response) {
            if (response.payload == null) return;
            try {
              handleTap(
                Map<String, dynamic>.from(jsonDecode(response.payload!) as Map),
              );
            } catch (_) {}
          },
        );

        // Create Android Notification Channel with MAX importance for heads-up alerts
        const androidChannel = AndroidNotificationChannel(
          _recoveraChannelId,
          _recoveraChannelName,
          description: _recoveraChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(androidChannel);
          await androidPlugin.requestNotificationsPermission();
        }

        // Request runtime notification permission for Android 13+ & iOS
        await _messaging!.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        FirebaseMessaging.onMessage.listen(_showForegroundNotification);
        FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => handleTap(message.data),
        );

        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) handleTap(initialMessage.data);
      }

      _bindTokenStreams();
      _bindConnectivityRetry();

      if (!_isTesting) {
        AuthRepository.instance.addListener(_registerCurrentInstallation);
        AuthRepository.instance.beforeLogoutDeviceProvider =
            () => currentDevicePayload;
      }

      await _acquireTokens();
      await registerCurrentInstallation();
    } catch (e) {
      _started = false;
      if (kDebugMode) debugPrint('Push init skipped/failed: $e');
    }
  }

  void _bindTokenStreams() {
    // firebase_messaging v17 marks getToken/onTokenRefresh deprecated in favor of FIDs,
    // but Android background FCM delivery requires an FCM registration token.
    final onTokenRefreshStream =
        // ignore: deprecated_member_use
        _onTokenRefreshOverride ?? _messaging?.onTokenRefresh;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = onTokenRefreshStream?.listen((token) {
      if (token.isNotEmpty) {
        _fcmToken = token;
        if (kDebugMode) debugPrint('🔥 [FCM TOKEN REFRESH]: $token');
        _registerCurrentInstallation();
      }
    });

    final onRegisteredStream =
        _onRegisteredOverride ?? _messaging?.onRegistered;
    _onRegisteredSub?.cancel();
    _onRegisteredSub = onRegisteredStream?.listen((fid) {
      if (fid.isNotEmpty) {
        _fid = fid;
        if (kDebugMode) debugPrint('🔥 [FIREBASE FID]: $fid');
        _registerCurrentInstallation();
      }
    });
  }

  void _bindConnectivityRetry() {
    final connectivityStream = _onConnectivityChangedOverride ??
        (_isTesting
            ? null
            : NetworkConnectivityService.instance.onConnectivityChanged);
    _connectivitySub?.cancel();
    _connectivitySub = connectivityStream?.listen((isOnline) {
      if (isOnline) {
        _registerCurrentInstallation();
      }
    });
  }

  Future<void> _acquireTokens() async {
    try {
      if (_registerFcmOverride != null) {
        await _registerFcmOverride();
      } else {
        await _messaging?.register();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error registering Firebase installation: $e');
    }

    try {
      final token = _getFcmTokenOverride != null
          ? await _getFcmTokenOverride()
          // ignore: deprecated_member_use
          : await _messaging?.getToken();
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
        if (kDebugMode) debugPrint('🔥 [FCM TOKEN]: $token');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching FCM token: $e');
    }
  }

  String? _expectedRegistrationKey(Map<String, String?> payload) {
    final uid = _currentUserId?.toString() ?? 'anon';
    final fcmToken = payload['fcm_token'];
    if (fcmToken != null && fcmToken.isNotEmpty) {
      return '$uid:fcm:$fcmToken';
    }
    final fid = payload['fid'];
    if (fid != null && fid.isNotEmpty) {
      return '$uid:fid:$fid';
    }
    return null;
  }

  Future<void> registerCurrentInstallation() async {
    final inFlight = _registrationInFlight;
    if (inFlight != null) {
      await inFlight;
      final payload = currentDevicePayload;
      if (!_isAuthenticated || _isAuthLoading || payload == null) return;
      final key = _expectedRegistrationKey(payload);
      if (key != null && key != _lastRegisteredKey) {
        return registerCurrentInstallation();
      }
      return;
    }

    final future = _performRegistration();
    _registrationInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_registrationInFlight, future)) {
        _registrationInFlight = null;
      }
    }
  }

  Future<void> _performRegistration() async {
    if (_isAuthLoading) return;
    if (!_isAuthenticated) {
      _lastRegisteredKey = null;
      return;
    }

    if (currentDevicePayload == null) {
      await _acquireTokens();
    }

    final payload = currentDevicePayload;
    if (payload == null) return;

    final registrationKey = _expectedRegistrationKey(payload);
    if (registrationKey != null && registrationKey == _lastRegisteredKey) {
      return;
    }

    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/devices',
        data: payload,
        options: Options(
          extra: {'ignore_session_expiration': true},
        ),
      );
      _lastRegisteredKey = registrationKey;
      if (kDebugMode) {
        debugPrint('✅ [DEVICE REGISTERED TO BACKEND]: ${res.data}');
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Unable to register push token: $error');
    }
  }

  void _registerCurrentInstallation() {
    registerCurrentInstallation();
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: _buildRecoveraNotificationDetails(),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: _buildRecoveraNotificationDetails(),
      payload: jsonEncode(message.data),
    );
  }

  void handleTap(Map<String, dynamic> data) {
    final navigator = AppNavigator.navigatorKey.currentState;
    if (navigator == null) return;
    switch (data['type']?.toString()) {
      case 'new_listing':
        final listingId = int.tryParse(data['listing_id']?.toString() ?? '');
        if (listingId != null) {
          navigator.pushNamed('/product/detail', arguments: listingId);
        }
        break;
      case 'new_order':
      case 'reminder':
        navigator.pushNamed('/seller/orders');
        break;
      case 'order_ready':
      case 'pickup_reminder':
        navigator.pushNamed('/buyer/transactions');
        break;
    }
  }
}
