// lib/services/rider_auth_service.dart
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/firebase_auth_adapter.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/session_context.dart';
import 'package:foodhub1/services/session_manager.dart';

/// Auth for the Rider side of the app. Separate from the customer
/// AuthService by design — riders sign in on their own screen with their
/// own credential store.
///
/// Credentials are verified by Firebase Auth whenever a backend is
/// reachable (this is what lets a rider registered on one device sign in
/// on another) and fall back to the local SHA-256 store when it is not.
/// The hash is mirrored onto the rider's Firestore document at register
/// and login time so the registry always carries it.
///
/// Demo accounts (seeded in AppData): jun@foodhub.com / rider123,
/// liza@foodhub.com / rider123
class RiderAuthService {
  RiderAuthService._();
  static final RiderAuthService instance = RiderAuthService._();

  /// email → SHA-256 password hash. Every entry (including the bundled
  /// demo accounts) is stored hashed, so signing in compares like with
  /// like whether the account came from this device, Firestore, or a
  /// fresh registration.
  final Map<String, String> _passwords = {
    'ace@foodhub.com': _hashOf('ace258'),
    'jun@foodhub.com': _hashOf('rider123'),
    'liza@foodhub.com': _hashOf('rider123'),
  };

  static String _hashOf(String password) =>
      FirebaseAuthAdapter.hash(password);

  RiderAccount? currentRider;

  /// Pulls rider credentials mirrored in Firestore back into the local
  /// store so an account registered on another device/app-run keeps
  /// working here. Idempotent and never throws (offline is a no-op).
  Future<void> hydrateFromFirestore() async {
    final hashes = await FirebaseSyncService.instance.fetchRiderPasswordHashes();
    if (hashes.isEmpty) return;
    for (final entry in hashes.entries) {
      _passwords[entry.key.trim().toLowerCase()] = entry.value;
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String vehicle,
  }) async {
    final key = email.trim().toLowerCase();
    if (_passwords.containsKey(key)) {
      return 'A rider account with this email already exists.';
    }

    final cloud =
        await FirebaseAuthAdapter.signUp(email: key, password: password);
    if (!cloud.ok && !cloud.offline) return cloud.error;

    final hash = _hashOf(password);
    _passwords[key] = hash;
    // Rider id == email, exactly like the Firestore document key, so a
    // rider is the same identity on every device.
    final rider = RiderAccount(
      id: key,
      name: name.trim(),
      email: key,
      vehicle: vehicle,
      passwordHash: hash,
    );
    AppData.instance.registerRider(rider);
    currentRider = rider;
    FirebaseSyncService.instance.upsertRider(rider);
    await SessionManager.onSignedIn(
      role: SessionRole.rider,
      email: key,
      name: name.trim(),
    );
    return null;
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final localHash = _passwords[key];
    final matchesLocal =
        localHash != null && localHash == _hashOf(password);

    if (FirebaseAuthAdapter.enabled) {
      final cloud =
          await FirebaseAuthAdapter.signIn(email: key, password: password);
      if (cloud.ok) return _finishLogin(key, password);
      if (!cloud.offline) {
        if (!matchesLocal) {
          return cloud.code == 'user-not-found'
              ? 'No rider account found with this email.'
              : (cloud.error ?? 'Incorrect password.');
        }
        // Demo/legacy riders must also get a Firebase Auth session, or
        // Firestore will deny their reads/writes (assigned deliveries,
        // availability, live location).
        final ensured = await FirebaseAuthAdapter.ensureSession(
            email: key, password: password);
        if (ensured.ok || ensured.offline) return _finishLogin(key, password);
        return ensured.error ?? cloud.error;
      }
      // offline → local verdict below.
    }

    if (localHash == null) return 'No rider account found with this email.';
    if (!matchesLocal) return 'Incorrect password.';
    await FirebaseAuthAdapter.ensureSession(email: key, password: password);
    return _finishLogin(key, password);
  }

  Future<String?> _finishLogin(String key, String password) async {
    final matches = AppData.instance.riders.where((r) => r.email == key);
    if (matches.isNotEmpty) {
      currentRider = matches.first;
      // Keep the (possibly new) credential hash on the account object so
      // the next upsert mirrors it instead of dropping it.
      final hashed = _passwords[key];
      if (hashed != null && currentRider!.passwordHash != hashed) {
        currentRider = RiderAccount(
          id: currentRider!.id,
          name: currentRider!.name,
          email: currentRider!.email,
          vehicle: currentRider!.vehicle,
          online: currentRider!.online,
          lastKnownLocation: currentRider!.lastKnownLocation,
          passwordHash: hashed,
        );
        AppData.instance.replaceRider(currentRider!);
      }
    } else {
      // Seeded demo credential with no matching AppData record yet —
      // create one on first login.
      final rider = RiderAccount(
        id: key,
        name: key.split('@').first,
        email: key,
        vehicle: 'Motorcycle',
        passwordHash: _passwords[key],
      );
      AppData.instance.registerRider(rider);
      currentRider = rider;
    }
    // Mirror onto the online rider registry (fresh position etc.).
    if (currentRider != null) {
      FirebaseSyncService.instance.upsertRider(currentRider!);
    }
    SessionContext.set(
        role: SessionRole.rider, email: key, name: currentRider?.name);
    await SessionManager.onSignedIn(role: SessionRole.rider, email: key);
    return null;
  }

  /// Rider's own online/offline switch (they stop receiving new
  /// deliveries when offline). Persisted to the cloud so restaurants and
  /// the admin see it immediately.
  Future<void> setOnline(bool online) async {
    final rider = currentRider;
    if (rider == null) return;
    rider.online = online;
    AppData.instance.notifyRiderChanged(rider);
    await FirebaseSyncService.instance.setRiderOnline(
      riderId: rider.id,
      online: online,
    );
  }

  Future<void> logout() async {
    currentRider = null;
    SessionContext.clear();
    await FirebaseAuthAdapter.signOut();
    await SessionManager.onSignedOut();
  }

  bool get isLoggedIn => currentRider != null;

  /// Restores a rider session that Firebase Auth still holds.
  Future<bool> restoreSession() async {
    final email = FirebaseAuthAdapter.currentAuthEmail;
    if (email == null || !FirebaseAuthAdapter.enabled) return false;
    final matches = AppData.instance.riders.where((r) => r.email == email);
    if (matches.isEmpty) return false;
    currentRider = matches.first;
    SessionContext.set(
        role: SessionRole.rider, email: email, name: currentRider!.name);
    return true;
  }
}
