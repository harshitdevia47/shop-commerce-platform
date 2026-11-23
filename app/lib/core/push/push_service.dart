import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/client_config.dart';

/// Push notifications for this phone. The server decides what to send (notification service);
/// the app registers its token and opens the page a tapped notification points to.
abstract interface class PushService {
  /// FCM registration token, or null when push is unavailable (no Firebase config, no Play services).
  Future<String?> token();

  /// New tokens (FCM rotates them occasionally): re-register with the server.
  Stream<String> get tokenRefresh;

  /// App routes from tapped notifications, e.g. `/orders/<id>`.
  Stream<String> get taps;

  /// The route of the notification that launched the app, once.
  Future<String?> takeLaunchRoute();

  /// Android 13+: asks for notification permission (shown once by the system).
  Future<void> requestPermission();
}

/// Builds without Firebase (tests, clients without google-services.json).
class NoPushService implements PushService {
  const NoPushService();

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<String?> takeLaunchRoute() async => null;

  @override
  Future<void> requestPermission() async {}
}

/// Android channel the server targets (`channel_id: orders`).
const ordersChannelId = 'orders';

/// FCM + local notifications. Firebase is initialized from build defines (see [FirebaseConfig]).
class FirebasePushService implements PushService {
  FirebasePushService._(this._messaging, this._local);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final _taps = StreamController<String>.broadcast();
  String? _launchRoute;

  /// Returns null (push disabled) when Firebase cannot start, e.g. no Google Play services.
  static Future<PushService> start(FirebaseConfig config, {required String channelName}) async {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config.apiKey,
          appId: config.appId,
          messagingSenderId: config.senderId,
          projectId: config.projectId,
        ),
      );
      final local = FlutterLocalNotificationsPlugin();
      final service = FirebasePushService._(FirebaseMessaging.instance, local);
      await service._init(channelName);
      return service;
    } on Object catch (error) {
      debugPrint('Push disabled: $error');
      return const NoPushService();
    }
  }

  Future<void> _init(String channelName) async {
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) => _tap(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(ordersChannelId, channelName, importance: Importance.high),
        );

    // In the foreground Android does not show FCM notifications itself.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      unawaited(
        _local.show(
          id: (message.data['orderId'] ?? message.messageId ?? '').hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(ordersChannelId, channelName, importance: Importance.high, priority: Priority.high),
          ),
          payload: message.data['route'] as String?,
        ),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _tap(message.data['route'] as String?));

    final initial = await _messaging.getInitialMessage();
    _launchRoute = initial?.data['route'] as String?;
    if (_launchRoute == null) {
      final details = await _local.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) _launchRoute = details!.notificationResponse?.payload;
    }
  }

  void _tap(String? route) {
    if (route != null && route.startsWith('/')) _taps.add(route);
  }

  @override
  Future<String?> token() async {
    try {
      // Classic registration token: what the server's FCM HTTP v1 `message.token` expects.
      // (firebase_messaging 17 prefers installation-id registration; switch together with the server.)
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } on Object catch (error) {
      debugPrint('No push token: $error');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchRoute() async {
    final route = _launchRoute;
    _launchRoute = null;
    return route;
  }

  @override
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }
}
