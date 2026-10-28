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
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  late final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiClient _apiClient = ApiClient();
  bool _started = false;
  String? _installationId;

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
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => handleTap(message.data),
      );
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) handleTap(initialMessage.data);
      _messaging.onRegistered.listen((installationId) {
        _installationId = installationId;
        _registerCurrentInstallation();
      });
      AuthRepository.instance.addListener(_registerCurrentInstallation);
      await _messaging.register();
      _started = true;
    } catch (error) {
      if (kDebugMode) debugPrint('Push notifications unavailable: $error');
    }
  }

  Future<void> _registerCurrentInstallation() async {
    if (!AuthRepository.instance.isAuthenticated) return;
    final installationId = _installationId;
    if (installationId == null || installationId.isEmpty) return;
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/devices',
        data: {'fid': installationId},
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Unable to register push token: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'recovera_notifications',
        'Notifikasi Recovera',
        channelDescription: 'Pembaruan pesanan dan penawaran Recovera',
        importance: Importance.high,
        priority: Priority.high,
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
        navigator.pushNamed('/buyer/transactions');
        break;
    }
  }
}
