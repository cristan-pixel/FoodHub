// lib/services/notification_service.dart
//
// Push + on-device notifications for every role.
//
//  • FCM permission/token handling and topic subscriptions, so a
//    customer can be reached at `customer_<email>`, a restaurant at
//    `restaurant_<email>`, a rider at `rider_<email>` and every admin
//    at `admins`. The Cloud Functions in `functions/` publish to those
//    same topics when an order (or its status) changes in Firestore.
//  • A local-notifications bridge for messages that arrive while the
//    app is in the foreground (system trays only auto-display pushes
//    that arrive while the app is backgrounded).
//
// Every call is defensive: without a configured Firebase project the
// service is a silent no-op and the app behaves exactly like before.

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'foodhub_orders';
  static const String _channelName = 'Order updates';
  static const String _channelDescription =
      'Live updates about your FoodHub orders and deliveries';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final Set<String> _topics = {};
  bool _initialized = false;

  /// Payload of the push the user tapped, as `key:value` — the app maps
  /// it onto the right screen. Broadcast so `main()` can subscribe once.
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();
  Stream<String> get onNotificationTap => _tapController.stream;

  /// Turns any email/role pair into a legal FCM topic name. Both the app
  /// and the Cloud Functions use this exact transform, so they always
  /// agree on the destination topic.
  static String topicFor(String role, String email) {
    final safe = email
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '${role}_$safe';
  }

  static const String adminTopic = 'admins';

  /// Requests permission, wires the foreground-message bridge and
  /// creates the notification channel. Safe to call repeatedly and
  /// never throws.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Local notifications first: they are also the foreground bridge
    // for FCM, so the channel must exist before any message can arrive.
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _local.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            _tapController.add(response.payload!);
          }
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ));
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Desktop / unsupported platform — no on-device notifications.
    }

    if (!FirebaseSyncService.instance.isEnabled) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        showLocal(
          n.title ?? 'FoodHub',
          n.body ?? '',
          payload: message.data['route']?.toString(),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final route = message.data['route']?.toString();
        if (route != null && route.isNotEmpty) _tapController.add(route);
      });
      // Re-subscribing is idempotent, so a token refresh later can
      // simply call [applyTopics] again.
      await messaging.getToken();
      await _flushSubscriptions();
    } catch (_) {
      // No Firebase / no network — in-app live updates still work.
    }
  }

  /// Shows an on-device notification (used for foregrounded pushes).
  Future<void> showLocal(String title, String body, {String? payload}) async {
    try {
      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  /// Subscribes this device to [topics] (idempotent).
  Future<void> subscribeTo(List<String> topics) async {
    var changed = false;
    for (final t in topics) {
      if (t.isEmpty || _topics.add(t)) {
        if (t.isNotEmpty) changed = true;
      }
    }
    if (changed) await _flushSubscriptions();
  }

  Future<void> _flushSubscriptions() async {
    if (!FirebaseSyncService.instance.isEnabled || _topics.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      for (final t in _topics) {
        await messaging.subscribeToTopic(t);
      }
    } catch (_) {}
  }

  /// Drops every topic subscription (called on sign-out so the next
  /// account on this device stops receiving someone else's pushes).
  Future<void> clearSubscriptions() async {
    if (_topics.isEmpty) return;
    if (FirebaseSyncService.instance.isEnabled) {
      try {
        final messaging = FirebaseMessaging.instance;
        for (final t in _topics) {
          await messaging.unsubscribeFromTopic(t);
        }
      } catch (_) {}
    }
    _topics.clear();
  }
}
