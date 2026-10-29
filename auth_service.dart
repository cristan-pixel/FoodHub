// lib/auth_service.dart
// Customer auth + customer profile store.
//
// Accounts are verified by Firebase Auth whenever a backend is
// reachable (that is what makes a signup on one device usable on
// another, and what lets the secured Firestore rules accept our reads
// and writes). Every account also keeps a local SHA-256 mirror so the
// app still signs people in when the network or the Firebase project is
// unavailable — the offline demo mode described in the README.
//
// The same store keeps the customer's profile (display name, phone,
// saved addresses, saved payment methods). It is written to Firestore
// (`users/{email}`) and mirrored into SharedPreferences so it survives
// restarts with or without a backend.

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/firebase_auth_adapter.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/session_context.dart';
import 'package:foodhub1/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _prefsPrefix = 'foodhub.profile.';

  // Map of email → SHA-256 password hash
  final Map<String, String> _users = {};

  // Map of email → display name (for admin customer list)
  final Map<String, String> _userNames = {};
  final Map<String, String> _userPhones = {};

  // email → saved delivery addresses (last entry is the one in use)
  final Map<String, List<String>> _addresses = {};
  final Map<String, List<Map<String, String>>> _paymentMethods = {};

  // Currently signed-in user info
  String? currentEmail;
  String? currentName;

  String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  /// All registered customers (email + name). Used by the admin
  /// dashboard to show the full user directory.
  List<Map<String, String>> get users => _users.keys
      .map((email) => {
            'email': email,
            'name': _userNames[email] ?? email.split('@').first,
          })
      .toList();

  // ── Profile accessors ────────────────────────────────────────────

  String get phone {
    final email = currentEmail;
    if (email == null) return '';
    return _userPhones[email] ?? '';
  }

  List<String> get addresses {
    final email = currentEmail;
    if (email == null) return const [];
    return List.unmodifiable(_addresses[email] ?? const []);
  }

  /// The address checkout should pre-fill: the most recently added one.
  String get defaultAddress {
    final list = addresses;
    return list.isEmpty ? '' : list.last;
  }

  List<Map<String, String>> get paymentMethods {
    final email = currentEmail;
    if (email == null) return const [];
    return List.unmodifiable(_paymentMethods[email] ?? const []);
  }

  /// Loyalty points earned by the signed-in customer: 1 point per peso
  /// spent on delivered orders (so the number always reflects reality
  /// instead of a hardcoded constant).
  int get loyaltyPoints {
    final email = currentEmail;
    if (email == null) return 0;
    final delivered = AppData.instance
        .ordersForCustomer(email)
        .where((o) => o.status == OrderStatus.delivered);
    var spent = 0.0;
    for (final o in delivered) {
      spent += o.total;
    }
    return spent.floor();
  }

  /// Stable per-account referral code (derived from the email, so it
  /// never changes and needs no storage).
  String get referralCode {
    final email = currentEmail ?? '';
    final digest = sha256.convert(utf8.encode(email)).toString();
    return 'FH${digest.substring(0, 8).toUpperCase()}';
  }

  // ── Registration / sign-in ───────────────────────────────────────

  /// Registers a new user. Returns null on success or an error message.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      return 'An account with this email already exists.';
    }

    final cloud = await FirebaseAuthAdapter.signUp(
      email: key,
      password: password,
    );
    if (!cloud.ok && !cloud.offline) {
      // A real backend rejected it (duplicate, weak password, bad
      // email…) — surface that instead of creating a local-only ghost.
      return cloud.error;
    }

    final hash = _hash(password);
    _users[key] = hash;
    _userNames[key] = name.trim();
    currentEmail = key;
    currentName = name.trim();

    FirebaseSyncService.instance.upsertUser(
      email: key,
      name: name.trim(),
      passwordHash: hash,
    );
    await _saveProfile(key);
    await SessionManager.onSignedIn(
      role: SessionRole.customer,
      email: key,
      name: name.trim(),
    );
    return null; // success
  }

  /// Sign in. Returns null on success, or an error message.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final localHash = _users[key];
    final matchesLocal = localHash != null && localHash == _hash(password);

    if (FirebaseAuthAdapter.enabled) {
      final cloud =
          await FirebaseAuthAdapter.signIn(email: key, password: password);
      if (cloud.ok) {
        await _finishLogin(key, password);
        return null;
      }
      if (!cloud.offline) {
        if (localHash == null) return cloud.error;
        if (!matchesLocal) return 'Incorrect password.';
        // Local/demo credentials also need a real Firebase Auth session so
        // Firestore reads and writes are not denied by the rules.
        final ensured = await FirebaseAuthAdapter.ensureSession(
            email: key, password: password);
        if (ensured.ok || ensured.offline) {
          await _finishLogin(key, password);
          return null;
        }
        return ensured.error ?? cloud.error;
      }
      // offline → fall through to the local verdict below.
    }

    if (localHash == null) {
      return 'No account found with this email.';
    }
    if (!matchesLocal) return 'Incorrect password.';
    // Offline sign-in: keep the cloud session attempt best-effort so the
    // rules-protected reads work as soon as the network returns.
    await FirebaseAuthAdapter.ensureSession(email: key, password: password);
    await _finishLogin(key, password);
    return null;
  }

  Future<void> _finishLogin(String key, String password) async {
    await _loadProfile(key);
    currentEmail = key;
    currentName = _userNames[key] ?? key.split('@').first;
    await SessionManager.onSignedIn(
      role: SessionRole.customer,
      email: key,
      name: currentName,
    );
  }

  /// Sends a Firebase password-reset email (works for accounts that
  /// exist in Firebase Auth; offline demo accounts can't be reset).
  Future<String?> sendPasswordReset(String email) async {
    if (!FirebaseAuthAdapter.enabled) {
      return 'Password reset needs an internet connection. Please try '
          'again later.';
    }
    final res = await FirebaseAuthAdapter.sendPasswordReset(email);
    if (res.ok) return null;
    if (res.code == 'user-not-found') {
      return 'No account found with this email.';
    }
    return res.error;
  }

  /// Changes the signed-in user's password. [currentPassword] guards
  /// against an unlocked phone being abused; [newPassword] is written
  /// to Firebase Auth and to the local/cloud mirror.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentEmail;
    if (email == null) return 'Please sign in first.';
    if (_users[email] != _hash(currentPassword)) {
      return 'Your current password is incorrect.';
    }
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters.';
    }
    if (newPassword == currentPassword) {
      return 'Choose a password different from your current one.';
    }

    final res = await FirebaseAuthAdapter.changePassword(newPassword);
    if (!res.ok && !res.offline) {
      if (res.code == 'requires-recent-login') {
        return 'For security, please sign out and sign in again, then '
            'retry changing your password.';
      }
      return res.error;
    }

    final hash = _hash(newPassword);
    _users[email] = hash;
    FirebaseSyncService.instance
        .upsertUser(email: email, name: currentName ?? email, passwordHash: hash);
    await _saveProfile(email);
    return null;
  }

  /// Permanently deletes the customer's account (cloud account, cloud
  /// profile doc and every local trace), then signs out.
  Future<String?> deleteAccount({required String password}) async {
    final email = currentEmail;
    if (email == null) return 'Please sign in first.';
    if (_users[email] != null && _users[email] != _hash(password)) {
      return 'Your password is incorrect.';
    }

    // Re-authenticate first: Firebase requires a fresh login before a
    // permanent delete, and this also validates the typed password.
    if (FirebaseAuthAdapter.enabled) {
      final reauth =
          await FirebaseAuthAdapter.signIn(email: email, password: password);
      if (!reauth.ok && !reauth.offline) {
        return reauth.error ?? 'Could not verify your password.';
      }
      if (!reauth.offline) {
        final del = await FirebaseAuthAdapter.deleteAccount();
        if (!del.ok && !del.offline) {
          if (del.code == 'requires-recent-login') {
            return 'For security, please sign out and sign in again, then '
                'retry deleting your account.';
          }
          return del.error;
        }
      }
    }

    await FirebaseSyncService.instance.deleteUser(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsPrefix$email');
    _users.remove(email);
    _userNames.remove(email);
    _userPhones.remove(email);
    _addresses.remove(email);
    _paymentMethods.remove(email);
    await logout();
    return null;
  }

  // ── Profile editing ──────────────────────────────────────────────

  /// Updates the signed-in user's display name (email is the login id
  /// and stays fixed) and mirrors the change to Firestore.
  void updateProfile({required String name, String? phone}) {
    final email = currentEmail;
    if (email == null) return;
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      _userNames[email] = trimmed;
      currentName = trimmed;
    }
    if (phone != null) {
      _userPhones[email] = phone.trim();
    }
    FirebaseSyncService.instance.upsertUser(
      email: email,
      name: _userNames[email] ?? trimmed,
      phone: _userPhones[email],
      addresses: _addresses[email],
      paymentMethods: _paymentMethods[email],
    );
    unawaited(_saveProfile(email));
  }

  Future<void> updatePhone(String phone) async {
    final email = currentEmail;
    if (email == null) return;
    _userPhones[email] = phone.trim();
    FirebaseSyncService.instance
        .upsertUser(email: email, name: _userNames[email] ?? email, phone: phone.trim());
    await _saveProfile(email);
  }

  Future<void> addAddress(String address) async {
    final email = currentEmail;
    final value = address.trim();
    if (email == null || value.isEmpty) return;
    final list = _addresses.putIfAbsent(email, () => []);
    if (list.contains(value)) return;
    list.add(value);
    FirebaseSyncService.instance.upsertUser(
      email: email,
      name: _userNames[email] ?? email,
      phone: _userPhones[email],
      addresses: list,
      paymentMethods: _paymentMethods[email],
    );
    await _saveProfile(email);
  }

  Future<void> removeAddress(String address) async {
    final email = currentEmail;
    if (email == null) return;
    _addresses[email]?.remove(address);
    FirebaseSyncService.instance.upsertUser(
      email: email,
      name: _userNames[email] ?? email,
      phone: _userPhones[email],
      addresses: _addresses[email],
      paymentMethods: _paymentMethods[email],
    );
    await _saveProfile(email);
  }

  Future<void> addPaymentMethod(
      {required String label, required String details}) async {
    final email = currentEmail;
    if (email == null) return;
    final list = _paymentMethods.putIfAbsent(email, () => []);
    list.add({'label': label.trim(), 'details': details.trim()});
    FirebaseSyncService.instance.upsertUser(
      email: email,
      name: _userNames[email] ?? email,
      phone: _userPhones[email],
      addresses: _addresses[email],
      paymentMethods: list,
    );
    await _saveProfile(email);
  }

  Future<void> removePaymentMethod(int index) async {
    final email = currentEmail;
    if (email == null) return;
    final list = _paymentMethods[email];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    FirebaseSyncService.instance.upsertUser(
      email: email,
      name: _userNames[email] ?? email,
      phone: _userPhones[email],
      addresses: _addresses[email],
      paymentMethods: list,
    );
    await _saveProfile(email);
  }

  // ── Local profile persistence ────────────────────────────────────

  Future<void> _saveProfile(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsPrefix$email',
        jsonEncode({
          'name': _userNames[email] ?? '',
          'phone': _userPhones[email] ?? '',
          'addresses': _addresses[email] ?? const [],
          'paymentMethods': _paymentMethods[email] ?? const [],
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadProfile(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix$email');
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final name = (data['name'] as String?) ?? '';
      if (name.isNotEmpty) _userNames[email] = name;
      _userPhones[email] = (data['phone'] as String?) ?? '';
      _addresses[email] =
          ((data['addresses'] as List?) ?? const []).cast<String>();
      _paymentMethods[email] =
          ((data['paymentMethods'] as List?) ?? const [])
              .map((e) => Map<String, String>.from(e as Map))
              .toList();
    } catch (_) {}
  }

  /// Pulls registered customers (and the signed-in profile) from
  /// Firestore into the local store so accounts and profile data persist
  /// across restarts. Never throws.
  Future<void> hydrateFromFirestore() async {
    if (!FirebaseSyncService.instance.isEnabled) return;
    final cloudUsers = await FirebaseSyncService.instance.fetchUsers();
    for (final u in cloudUsers) {
      final email = u['email'] ?? '';
      if (email.isEmpty) continue;
      final name = u['name'] ?? email.split('@').first;
      _userNames[email] = name;
      final hash = u['passwordHash'] ?? '';
      if (hash.isNotEmpty) {
        _users[email] = hash;
      }
    }
    // The signed-in account's full profile (phone, addresses, payments).
    final email =
        FirebaseAuthAdapter.currentAuthEmail ?? currentEmail;
    if (email != null) {
      final profile = await FirebaseSyncService.instance.fetchUser(email);
      if (profile != null) {
        _applyProfile(email, profile);
        currentName = _userNames[email] ?? currentName;
      }
      await _loadProfile(email);
    }
  }

  void _applyProfile(String email, Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? '';
    if (name.isNotEmpty) _userNames[email] = name;
    final phone = (data['phone'] as String?) ?? '';
    if (phone.isNotEmpty) _userPhones[email] = phone;
    final addrs = (data['addresses'] as List?) ?? const [];
    if (addrs.isNotEmpty) {
      _addresses[email] = addrs.map((e) => '$e').toList();
    }
    final pays = (data['paymentMethods'] as List?) ?? const [];
    if (pays.isNotEmpty) {
      _paymentMethods[email] = pays
          .whereType<Map>()
          .map((e) => Map<String, String>.from(e))
          .toList();
    }
  }

  bool _usersStreamAttached = false;

  /// Keeps the admin's customer directory live: mirrors the Firestore
  /// users stream into the local store so customers who sign up anywhere
  /// show up without a restart. Safe to call repeatedly; never throws.
  void attachUsersStream() {
    if (_usersStreamAttached) return;
    _usersStreamAttached = true;
    final firebase = FirebaseSyncService.instance;
    if (!firebase.isEnabled) return;
    firebase.streamUsers().listen((cloudUsers) {
      for (final u in cloudUsers) {
        final email = u['email'] ?? '';
        if (email.isEmpty) continue;
        final name = u['name'] ?? email.split('@').first;
        _userNames[email] = name;
        _users.putIfAbsent(email, () => '');
      }
    }, onError: (_) {
      // Stream dropped (offline/rules) — the local store is unaffected.
    });
  }

  Future<void> logout() async {
    currentEmail = null;
    currentName = null;
    SessionContext.clear();
    await FirebaseAuthAdapter.signOut();
    await SessionManager.onSignedOut();
  }

  /// The stored SHA-256 hash for an account email (used by the social-auth
  /// mirror so Firestore's user directory always has a consistent hash field,
  /// exactly like the email/password path).
  String? passwordHashFor(String email) =>
      _users[email.trim().toLowerCase()];

  bool get isLoggedIn => currentEmail != null;

  /// Restores a customer session that Firebase Auth still holds (app
  /// restarted while signed in). Returns the email when restored.
  Future<String?> restoreSession() async {
    final email = FirebaseAuthAdapter.currentAuthEmail;
    if (email == null) return null;
    if (FirebaseAuthAdapter.enabled) {
      await _loadProfile(email);
      currentEmail = email;
      currentName = _userNames[email] ?? email.split('@').first;
      SessionContext.set(
          role: SessionRole.customer, email: email, name: currentName);
      return email;
    }
    return null;
  }
}
