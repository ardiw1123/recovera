import 'package:dio/dio.dart';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/navigation/app_navigator.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/auth_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notification = message.notification;
  if (notification != null) {
    final localNotifications = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotifications.initialize(settings: const InitializationSettings(android: android));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'recovera_notifications',
        'Notifikasi Recovera',
        channelDescription: 'Pembaruan pesanan dan penawaran Recovera',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  late final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  ApiClient get _apiClient => AuthRepository.instance.authApiService.client;
  bool _started = false;
  String? _fcmToken;

  Future<void> init() async {
    if (_started) return;
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

      // Create Android Notification Channel with HIGH importance for Heads-Up notification
      const androidChannel = AndroidNotificationChannel(
        'recovera_notifications',
        'Notifikasi Recovera',
        description: 'Pembaruan pesanan dan penawaran Recovera',
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
      await _messaging.requestPermission(
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

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) handleTap(initialMessage.data);

      // Retrieve FCM device token via v17+ registration API
      _messaging.onRegistered.listen((token) {
        if (token.isNotEmpty) {
          _fcmToken = token;
          _registerCurrentInstallation();
        }
      });

      try {
        await _messaging.register();
      } catch (e) {
        if (kDebugMode) debugPrint('Error registering FCM token: $e');
      }

      AuthRepository.instance.addListener(_registerCurrentInstallation);
      _started = true;
    } catch (error) {
      if (kDebugMode) debugPrint('Push notifications unavailable: $error');
    }
  }

  Future<void> registerCurrentInstallation() async {
    if (!AuthRepository.instance.isAuthenticated ||
        AuthRepository.instance.isLoading) {
      return;
    }
    final token = _fcmToken;
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/devices',
        data: {'fcm_token': token},
        options: Options(
          extra: {'ignore_session_expiration': true},
        ),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Unable to register push token: $error');
    }
  }

  void _registerCurrentInstallation() {
    registerCurrentInstallation();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'recovera_notifications',
        'Notifikasi Recovera',
        channelDescription: 'Pembaruan pesanan dan penawaran Recovera',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
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
