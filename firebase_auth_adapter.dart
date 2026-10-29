// lib/services/firebase_auth_adapter.dart
//
// The single Firebase Auth gateway shared by every role (customer,
// rider, restaurant partner, admin).
//
// Why one adapter: each role keeps its own local credential store so the
// app still runs in offline demo mode, but whenever Firebase is
// reachable the cloud session wins. That is what makes an account
// registered on one device sign in on another, and what lets the
// secured Firestore rules accept our reads and writes.
//
// Every method is defensive: when Firebase is not configured, or the
// network is down, the adapter reports `offline` and the caller falls
// back to its local store instead of blocking the user.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';

class AuthResult {
  const AuthResult._({this.error, this.code, this.offline = false});

  /// Human-readable failure, or null on success.
  final String? error;

  /// Raw FirebaseAuthException code so callers can branch (e.g. fall
  /// back to the local store on `user-not-found`).
  final String? code;

  /// True when Firebase is unreachable/not configured and the caller
  /// should decide what to do using its local credential store.
  final bool offline;

  bool get ok => error == null;

  static const AuthResult success = AuthResult._();
  static const AuthResult offlineResult = AuthResult._(offline: true);
  static AuthResult failure(String message, {String? code}) =>
      AuthResult._(error: message, code: code);
}

class FirebaseAuthAdapter {
  FirebaseAuthAdapter._();

  /// SHA-256 of a password — the format used by every local credential
  /// store and mirrored into Firestore (`passwordHash` fields).
  static String hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  static bool get enabled => FirebaseSyncService.instance.isEnabled;

  static FirebaseAuth? get _auth {
    if (!enabled) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  static String? get _uidOrNull {
    try {
      return _auth?.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static String? get currentUid => _uidOrNull;
  static String? get currentAuthEmail {
    try {
      return _auth?.currentUser?.email?.trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  static String? _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact an administrator.';
      case 'requires-recent-login':
        return 'Please sign in again before making this change.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  static AuthResult _from(Object error) {
    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed' ||
          error.code == 'network-error') {
        return AuthResult.offlineResult;
      }
      // The project's Authentication backend isn't initialized yet
      // (console: Authentication -> Get started). Treat it like any other
      // unreachable backend so the app keeps working in local mode
      // instead of blocking every sign-in/up.
      if (error.code == 'internal-error' ||
          error.code == 'unknown' ||
          (error.message ?? '').contains('CONFIGURATION_NOT_FOUND')) {
        return AuthResult.offlineResult;
      }
      return AuthResult.failure(_friendly(error)!, code: error.code);
    }
    // Anything else (plugin missing, platform channel failure, timeout…)
    // means "can't reach the backend right now".
    return AuthResult.offlineResult;
  }

  /// Signs in with an email + password.
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final fa = _auth;
    if (fa == null) return AuthResult.offlineResult;
    try {
      await fa.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return AuthResult.success;
    } catch (e) {
      return _from(e);
    }
  }

  /// Creates the cloud account (and signs the user in).
  static Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    final fa = _auth;
    if (fa == null) return AuthResult.offlineResult;
    try {
      await fa.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return AuthResult.success;
    } catch (e) {
      final res = _from(e);
      // The account may already exist in the cloud but not on this
      // device's local store (e.g. re-install) — treat it as a
      // duplicate so the UI shows the right message.
      if (res.code == 'email-already-in-use') return res;
      return res;
    }
  }

  /// Ensures the Firebase Auth session belongs to [email], creating the
  /// cloud account when it only exists in the local demo store.
  ///
  /// Firebase projects with email-enumeration protection return
  /// `invalid-credential` (not `user-not-found`) for a missing account, so
  /// this always retries with sign-up instead of relying on that code.
  /// Returns [AuthResult.offlineResult] when the backend is unreachable;
  /// callers may then continue in local-only mode.
  static Future<AuthResult> ensureSession({
    required String email,
    required String password,
  }) async {
    final fa = _auth;
    if (fa == null) return AuthResult.offlineResult;
    final normalized = email.trim().toLowerCase();
    if (fa.currentUser != null &&
        fa.currentUser?.email?.trim().toLowerCase() == normalized) {
      return AuthResult.success;
    }
    // Already signed in as somebody else — sign out first so the
    // bootstrap below creates/enters the right account.
    if (fa.currentUser != null) {
      try {
        await fa.signOut();
      } catch (_) {}
    }

    final signInResult = await signIn(email: normalized, password: password);
    if (signInResult.ok || signInResult.offline) return signInResult;

    // The account does not exist yet (enumeration protection hides this as
    // invalid-credential), so provision it with the password the user just
    // verified against the local store.
    final signUpResult = await signUp(email: normalized, password: password);
    if (signUpResult.ok || signUpResult.offline) return signUpResult;

    if (signUpResult.code == 'email-already-in-use') {
      return AuthResult.failure(
        'This email is registered online with a different password. '
        'Sign in with your online password or reset it.',
        code: 'cloud-password-mismatch',
      );
    }
    return signUpResult;
  }

  static Future<AuthResult> signOut() async {
    final fa = _auth;
    if (fa == null) return AuthResult.success;
    try {
      await fa.signOut();
      return AuthResult.success;
    } catch (e) {
      return _from(e);
    }
  }

  static Future<AuthResult> changePassword(String newPassword) async {
    final fa = _auth;
    if (fa == null) return AuthResult.offlineResult;
    try {
      final user = fa.currentUser;
      if (user == null) {
        return AuthResult.failure('Please sign in first.', code: 'no-user');
      }
      await user.updatePassword(newPassword);
      return AuthResult.success;
    } catch (e) {
      return _from(e);
    }
  }

  static Future<AuthResult> sendPasswordReset(String email) async {
    final fa = _auth;
    if (fa == null) return AuthResult.offlineResult;
    try {
      await fa.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return AuthResult.success;
    } catch (e) {
      return _from(e);
    }
  }

  /// Permanently removes the signed-in account (used by "Delete
  /// account" in the profile). Requires a recent login for safety, so
  /// callers should surface [AuthResult.error] when it comes back.
  static Future<AuthResult> deleteAccount() async {
    final fa = _auth;
    if (fa == null) return AuthResult.offlineResult;
    try {
      final user = fa.currentUser;
      if (user == null) {
        return AuthResult.failure('Please sign in first.', code: 'no-user');
      }
      await user.delete();
      return AuthResult.success;
    } catch (e) {
      return _from(e);
    }
  }
}
