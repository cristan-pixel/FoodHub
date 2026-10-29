// lib/services/restaurant_auth_service.dart
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/firebase_auth_adapter.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/session_context.dart';
import 'package:foodhub1/services/session_manager.dart';

/// Auth for the Restaurant-partner side of the app.
///
/// Credentials are verified by Firebase Auth whenever a backend is
/// reachable, with the local SHA-256 store as the offline fallback, and
/// the hash is mirrored onto the partner's Firestore document so a
/// registration on one device works on another.
///
/// Demo accounts (all password `rest123`):
///  jb@foodhub.com        → JB LutongBahay Resto
///  bibiana@foodhub.com   → Bibiana FoodHouse
///  mamos@foodhub.com     → Mamos Tasty Ramen
///  pareng@foodhub.com    → Pareng Eling
///  pastilan@foodhub.com  → Pastilan
class RestaurantAuthService {
  RestaurantAuthService._();
  static final RestaurantAuthService instance = RestaurantAuthService._();

  /// email → SHA-256 password hash (every entry, including the demo
  /// accounts, is stored hashed so login always compares like with like).
  final Map<String, String> _passwords = {
    for (final email in const [
      'jb@foodhub.com',
      'bibiana@foodhub.com',
      'mamos@foodhub.com',
      'pareng@foodhub.com',
      'pastilan@foodhub.com',
    ])
      email: _hashOf('rest123'),
  };

  static String _hashOf(String password) =>
      FirebaseAuthAdapter.hash(password);

  RestaurantAccount? currentRestaurant;

  /// Pulls restaurant-partner credentials mirrored in Firestore back into
  /// the local store so an account registered on another device/app-run
  /// keeps working here. Idempotent and never throws.
  Future<void> hydrateFromFirestore() async {
    final hashes =
        await FirebaseSyncService.instance.fetchRestaurantPasswordHashes();
    if (hashes.isEmpty) return;
    for (final entry in hashes.entries) {
      _passwords[entry.key.trim().toLowerCase()] = entry.value;
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String cuisine,
    required String address,
  }) async {
    final key = email.trim().toLowerCase();
    if (_passwords.containsKey(key)) {
      return 'A restaurant account with this email already exists.';
    }

    final cloud =
        await FirebaseAuthAdapter.signUp(email: key, password: password);
    if (!cloud.ok && !cloud.offline) return cloud.error;

    final hash = _hashOf(password);
    _passwords[key] = hash;
    final restaurant = RestaurantAccount(
      // Partner id == email, matching the Firestore document key.
      id: key,
      name: name.trim(),
      email: key,
      cuisine: cuisine,
      address: address,
      // New partners default near the delivery city center (Tangub
      // City); in production geocode `address` instead.
      location: const GeoPoint(8.0660, 123.7480),
      passwordHash: hash,
    );
    AppData.instance.registerRestaurant(restaurant);
    currentRestaurant = restaurant;
    FirebaseSyncService.instance.upsertRestaurant(restaurant);
    await SessionManager.onSignedIn(
      role: SessionRole.restaurant,
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
      if (cloud.ok) return _finishLogin(key);
      if (!cloud.offline) {
        if (!matchesLocal) {
          return cloud.code == 'user-not-found'
              ? 'No restaurant account found with this email.'
              : (cloud.error ?? 'Incorrect password.');
        }
        // A valid local/demo credential must also get a Firebase Auth
        // session, otherwise every Firestore write (accepting an order,
        // assigning a rider) is silently denied by the rules.
        final ensured = await FirebaseAuthAdapter.ensureSession(
            email: key, password: password);
        if (ensured.ok || ensured.offline) return _finishLogin(key);
        return ensured.error ?? cloud.error;
      }
      // offline → local verdict below.
    }

    if (localHash == null) {
      return 'No restaurant account found with this email.';
    }
    if (!matchesLocal) return 'Incorrect password.';
    await FirebaseAuthAdapter.ensureSession(email: key, password: password);
    return _finishLogin(key);
  }

  Future<String?> _finishLogin(String key) async {
    final matches = AppData.instance.restaurants.where((r) => r.email == key);
    if (matches.isNotEmpty) {
      currentRestaurant = matches.first;
      final hashed = _passwords[key];
      if (hashed != null && currentRestaurant!.passwordHash != hashed) {
        currentRestaurant = RestaurantAccount(
          id: currentRestaurant!.id,
          name: currentRestaurant!.name,
          email: currentRestaurant!.email,
          cuisine: currentRestaurant!.cuisine,
          address: currentRestaurant!.address,
          location: currentRestaurant!.location,
          acceptingOrders: currentRestaurant!.acceptingOrders,
          passwordHash: hashed,
        );
        AppData.instance.replaceRestaurant(currentRestaurant!);
      }
    }
    // Mirror onto the online partner registry.
    if (currentRestaurant != null) {
      FirebaseSyncService.instance.upsertRestaurant(currentRestaurant!);
    }
    SessionContext.set(
        role: SessionRole.restaurant,
        email: key,
        name: currentRestaurant?.name);
    await SessionManager.onSignedIn(
        role: SessionRole.restaurant, email: key);
    return null;
  }

  /// Pauses/resumes incoming orders for this partner.
  Future<void> setAcceptingOrders(bool accepting) async {
    final restaurant = currentRestaurant;
    if (restaurant == null) return;
    restaurant.acceptingOrders = accepting;
    AppData.instance.notifyRestaurantChanged(restaurant);
    await FirebaseSyncService.instance.setRestaurantAccepting(
      restaurantEmail: restaurant.email,
      accepting: accepting,
    );
  }

  Future<void> logout() async {
    currentRestaurant = null;
    SessionContext.clear();
    await FirebaseAuthAdapter.signOut();
    await SessionManager.onSignedOut();
  }

  bool get isLoggedIn => currentRestaurant != null;

  /// Restores a partner session that Firebase Auth still holds.
  Future<bool> restoreSession() async {
    final email = FirebaseAuthAdapter.currentAuthEmail;
    if (email == null || !FirebaseAuthAdapter.enabled) return false;
    final matches = AppData.instance.restaurants.where((r) => r.email == email);
    if (matches.isEmpty) return false;
    currentRestaurant = matches.first;
    SessionContext.set(
        role: SessionRole.restaurant,
        email: email,
        name: currentRestaurant!.name);
    return true;
  }
}
