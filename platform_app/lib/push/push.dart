import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overdue alerts from the platform service (`channel_id: alerts`, data `shopId`).
abstract interface class AdminPush {
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// Shop ids of tapped notifications.
  Stream<String> get taps;

  /// The shop of the notification that started the app, once.
  Future<String?> takeLaunchShop();
  Future<void> requestPermission();
}

/// No Firebase values in the build (tests, before Firebase is set up): alerts come by email.
class NoPush implements AdminPush {
  const NoPush();
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<String> get taps => const Stream.empty();
  @override
  Future<String?> takeLaunchShop() async => null;
  @override
  Future<void> requestPermission() async {}
}

const alertsChannel = 'alerts';

/// Firebase values from `config/firebase.json` (made by `dart run tool/firebase_defines.dart`).
class FirebaseValues {
  const FirebaseValues({required this.apiKey, required this.appId, required this.senderId, required this.projectId});
  final String apiKey;
  final String appId;
  final String senderId;
  final String projectId;

  static FirebaseValues? fromEnvironment() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty) return null;
    return const FirebaseValues(apiKey: apiKey, appId: appId, senderId: senderId, projectId: projectId);
  }
}

class FirebaseAdminPush implements AdminPush {
  FirebaseAdminPush._(this._messaging, this._local);
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final _taps = StreamController<String>.broadcast();
  String? _launchShop;

  static Future<AdminPush> start(FirebaseValues values) async {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(apiKey: values.apiKey, appId: values.appId, messagingSenderId: values.senderId, projectId: values.projectId),
      );
      final push = FirebaseAdminPush._(FirebaseMessaging.instance, FlutterLocalNotificationsPlugin());
      await push._init();
      return push;
    } on Object catch (error) {
      debugPrint('Notifications off: $error');
      return const NoPush();
    }
  }

  Future<void> _init() async {
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) => _tap(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(alertsChannel, 'Overdue shops', importance: Importance.high));

    // In the foreground Android does not show FCM notifications itself.
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      unawaited(
        _local.show(
          id: (message.data['shopId'] ?? message.messageId ?? '').hashCode,
          title: n.title,
          body: n.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(alertsChannel, 'Overdue shops', importance: Importance.high, priority: Priority.high),
          ),
          payload: message.data['shopId'] as String?,
        ),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _tap(message.data['shopId'] as String?));
    _launchShop = (await _messaging.getInitialMessage())?.data['shopId'] as String?;
    if (_launchShop == null) {
      final details = await _local.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) _launchShop = details!.notificationResponse?.payload;
    }
  }

  void _tap(String? shopId) {
    if (shopId != null && shopId.isNotEmpty) _taps.add(shopId);
  }

  @override
  Future<String?> token() async {
    try {
      // Classic registration token, what FCM HTTP v1 `message.token` expects (same as the shop apps).
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } on Object catch (error) {
      debugPrint('No notification token: $error');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchShop() async {
    final shop = _launchShop;
    _launchShop = null;
    return shop;
  }

  @override
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }
}

final adminPushProvider = Provider<AdminPush>((ref) => const NoPush());
