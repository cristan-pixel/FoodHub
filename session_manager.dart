// lib/services/session_manager.dart
//
// Everything that has to happen the moment somebody signs in or out,
// in one place, so every role gets identical behaviour:
//
//  • re-attach the live Firestore subscriptions (the first attempt runs
//    before anyone is signed in, so the secured rules deny it),
//  • push the bundled catalog (writing now requires an authenticated
//    user),
//  • subscribe/unsubscribe this device to its push topics,
//  • remember the active role so the next launch restores the session.
//
// Every step is fire-and-forget and never throws: a missing backend or
// a dropped connection must never block a sign-in.

import 'dart:async';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/firebase_auth_adapter.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/notification_service.dart';
import 'package:foodhub1/services/session_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:foodhub1/services/session_context.dart' show SessionRole;

class SessionManager {
  SessionManager._();

  static const String _keyRole = 'foodhub.session.role';
  static const String _keyEmail = 'foodhub.session.email';

  static SessionRole? restoredRole;
  static String? restoredEmail;

  /// Reads the persisted session (called once from `main()` before the
  /// first frame). Combined with [FirebaseAuthAdapter] this decides
  /// whether the app can resume straight into a dashboard.
  static Future<void> loadPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_keyRole);
      final email = prefs.getString(_keyEmail);
      if (role == null || email == null || email.isEmpty) return;
      // Only trust the stored session when Firebase still holds a
      // matching session — otherwise the account was signed out or the
      // token expired and we fall back to the role picker.
      if (FirebaseAuthAdapter.currentAuthEmail != email) return;
      restoredRole = SessionRole.values.firstWhere(
        (r) => r.name == role,
        orElse: () => SessionRole.customer,
      );
      restoredEmail = email;
    } catch (_) {
      // Preferences unavailable — treat as a fresh launch.
    }
  }

  static Future<void> _remember(SessionRole role, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRole, role.name);
      await prefs.setString(_keyEmail, email);
    } catch (_) {}
  }

  static Future<void> forget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRole);
      await prefs.remove(_keyEmail);
    } catch (_) {}
  }

  /// Hook run after a successful sign-in, from any role's auth service.
  static Future<void> onSignedIn({
    required SessionRole role,
    required String email,
    String? name,
  }) async {
    SessionContext.set(role: role, email: email, name: name);
    await _remember(role, email);
    final firebase = FirebaseSyncService.instance;
    if (!firebase.isEnabled) return;

    // Catalog writes now have an authenticated author — seed once more
    // so a brand-new backend fills up on the first sign-in.
    unawaited(firebase.seedCatalog());

    // The startup listeners were started anonymously and were denied by
    // the rules; rebuild them now that we have a session. Bounded so a
    // slow network can never hold the sign-in spinner forever.
    await AppData.instance
        .attachFirestoreStreams(force: true)
        .timeout(const Duration(seconds: 6), onTimeout: () {});

    await NotificationService.instance.subscribeTo([
      NotificationService.topicFor(_topicRole(role), email),
      if (role == SessionRole.admin) NotificationService.adminTopic,
    ]);
  }

  /// Hook run after a sign-out: stop this device from receiving the
  /// previous account's pushes and drop the persisted session.
  static Future<void> onSignedOut() async {
    await NotificationService.instance.clearSubscriptions();
    await forget();
  }

  static String _topicRole(SessionRole role) {
    switch (role) {
      case SessionRole.customer:
        return 'customer';
      case SessionRole.rider:
        return 'rider';
      case SessionRole.restaurant:
        return 'restaurant';
      case SessionRole.admin:
        return 'admin';
    }
  }
}
