// lib/services/admin_auth_service.dart
import 'package:foodhub1/services/firebase_auth_adapter.dart';
import 'package:foodhub1/services/session_context.dart';
import 'package:foodhub1/services/session_manager.dart';

/// Admin accounts are provisioned by you, not self-registered — so this
/// is login-only. Launch credentials: admin@foodhub.com / FoodHub!Admin#2026
///
/// The credentials are verified by Firebase Auth whenever a backend is
/// reachable (the account is provisioned into Firebase Auth on first
/// successful use) and fall back to the built-in check when the app runs
/// in offline demo mode. For a real deployment change the password here
/// — and in the Firebase console — before shipping.
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  static const _email = 'admin@foodhub.com';
  static const _password = 'FoodHub!Admin#2026';

  bool _loggedIn = false;
  bool get isLoggedIn => _loggedIn;

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    if (key != _email) return 'Invalid admin credentials.';

    if (FirebaseAuthAdapter.enabled) {
      final cloud = await FirebaseAuthAdapter.signIn(
          email: key, password: password);
      if (cloud.ok) return _finish();
      if (!cloud.offline) {
        if (password != _password) return 'Invalid admin credentials.';
        // First online use (or enumeration-protected missing account):
        // provision the admin into Firebase Auth with the shipped creds.
        final ensured = await FirebaseAuthAdapter.ensureSession(
            email: key, password: password);
        if (ensured.ok || ensured.offline) return _finish();
        return ensured.error ?? 'Invalid admin credentials.';
      }
      // offline → local check below.
    }

    if (password != _password) return 'Invalid admin credentials.';
    await FirebaseAuthAdapter.ensureSession(email: key, password: password);
    return _finish();
  }

  Future<String?> _finish() async {
    _loggedIn = true;
    SessionContext.set(role: SessionRole.admin, email: _email);
    await SessionManager.onSignedIn(role: SessionRole.admin, email: _email);
    return null;
  }

  Future<void> logout() async {
    _loggedIn = false;
    SessionContext.clear();
    await FirebaseAuthAdapter.signOut();
    await SessionManager.onSignedOut();
  }

  /// Restores an admin session that Firebase Auth still holds.
  Future<bool> restoreSession() async {
    final email = FirebaseAuthAdapter.currentAuthEmail;
    if (email == _email && FirebaseAuthAdapter.enabled) {
      _loggedIn = true;
      SessionContext.set(role: SessionRole.admin, email: _email);
      return true;
    }
    return false;
  }
}
