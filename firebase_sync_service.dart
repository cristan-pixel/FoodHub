// lib/services/firebase_sync_service.dart
//
// The app's Firestore database layer. Everything that should exist
// "online" (orders, customers, riders, restaurant partners, and the
// restaurant/menu catalog) is read from and written to a Firestore
// collection here, then mirrored into the in-memory AppData store so
// every screen keeps working exactly as before.
//
// If Firebase is not configured on this device/build (no
// google-services.json, no firebase_options, desktop without the
// plugin, ...), every call becomes a silent no-op and the app keeps
// running on the local demo store — it never crashes or blocks.
//
// To go online: create a Firebase project, run `flutterfire configure`,
// upload the firestore.rules shipped with this project, and run the
// app. See README.md ▸ "Going online with Firebase".
//
// Rider GPS handling lives here too: it throttles the high-frequency
// geolocator stream to one Firestore write every few seconds, writing
// each fix under orders/{orderId}/riderLocation/{autoId} and also
// refreshing a `lastRiderLocation` map on the order document so readers
// can grab the latest position in one read.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:foodhub1/firebase_options.dart';
import 'package:foodhub1/menu_items.dart';
import 'package:foodhub1/models/order_models.dart' as models;
import 'package:foodhub1/services/seed_data.dart';

class FirebaseSyncService {
  FirebaseSyncService._();
  static final FirebaseSyncService instance = FirebaseSyncService._();

  /// Minimum gap between Firestore location writes ("every few seconds").
  static const Duration minWriteInterval = Duration(seconds: 5);

  bool _initialized = false;
  Future<void>? _initializing;
  final Map<String, DateTime> _lastPushAt = {};

  bool get isEnabled => _initialized;

  /// Tries to start Firebase. Safe to call repeatedly; never throws.
  /// Call from `main()` so the first Firestore write is never blocked by
  /// a lazy one-time init.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_initializing != null) return _initializing;
    final future = _init();
    _initializing = future;
    try {
      await future;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _init() async {
    // 1) Preferred: a real firebase_options.dart (written by
    //    `flutterfire configure` or filled in by hand).
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      return;
    } catch (_) {
      // fall through to the default (google-services.json etc.)
    }
    // 2) Fallback: platform-default config (Android google-services.json…).
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (_) {
      // No backend configured anywhere — stay in online demo mode.
      _initialized = false;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Catalog: restaurants + their menus (one-time idempotent seed)
  // ════════════════════════════════════════════════════════════════

  /// Writes the bundled restaurant accounts and their menus into
  /// Firestore using merge, so running it any number of times never
  /// duplicates or overwrites newer data.
  ///
  ///   restaurants/{email}            → account + display metadata
  ///   restaurants/{email}/menus/…    → menu items
  Future<void> seedCatalog() async {
    if (!_initialized) return;
    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      for (final seed in seedRestaurants) {
        final Map<String, String> catalog = allRestaurants.firstWhere(
          (r) => r['name'] == seed.name,
          orElse: () => const {},
        );
        final ref = fs.collection('restaurants').doc(seed.email);
        batch.set(
          ref,
          {
            'name': seed.name,
            'email': seed.email,
            'cuisine': seed.cuisine,
            'address': seed.address,
            'location': GeoPoint(seed.lat, seed.lng),
            'acceptingOrders': true,
            if (catalog['tags'] != null) 'tags': catalog['tags'],
            if (catalog['rating'] != null) 'rating': catalog['rating'],
            if (catalog['category'] != null) 'category': catalog['category'],
            if (catalog['price'] != null) 'deliveryPrice': catalog['price'],
            if (catalog['prep'] != null) 'prepTime': catalog['prep'],
          },
          SetOptions(merge: true),
        );
        final menu = restaurantMenus[seed.name] ?? [];
        for (var j = 0; j < menu.length; j++) {
          batch.set(
            ref.collection('menus').doc('item$j'),
            Map<String, dynamic>.from(menu[j]),
            SetOptions(merge: true),
          );
        }
      }
      // Seed the demo riders too so the admin registry is populated
      // from day one.
      for (final rider in seedRiders) {
        batch.set(
          fs.collection('riders').doc(rider.email),
          {
            'name': rider.name,
            'email': rider.email,
            'vehicle': rider.vehicle,
            'online': true,
            'location': GeoPoint(rider.lat, rider.lng),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (_) {
      // Offline / rules block us — the bundled catalog still works.
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Customers (users)
  // ════════════════════════════════════════════════════════════════

  /// Mirrors a registered customer account so the admin's customer
  /// directory and (on the same device) subsequent logins stay cloud-persisted.
  ///
  ///   users/{email} → { name, email, passwordHash, phone, addresses,
  ///                      paymentMethods, createdAt }
  Future<void> upsertUser({
    required String email,
    required String name,
    String? passwordHash,
    String? phone,
    List<String>? addresses,
    List<Map<String, String>>? paymentMethods,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'email': email,
        'name': name,
        if (passwordHash != null) 'passwordHash': passwordHash,
        if (phone != null) 'phone': phone,
        if (addresses != null) 'addresses': addresses,
        if (paymentMethods != null) 'paymentMethods': paymentMethods,
        'createdAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Full profile document for one customer (name, phone, addresses,
  /// payment methods). Returns null when the doc is missing/unreadable.
  Future<Map<String, dynamic>?> fetchUser(String email) async {
    if (!_initialized) return null;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(email).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Removes a customer's profile document (account deletion).
  Future<void> deleteUser(String email) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(email).delete();
    } catch (_) {}
  }

  /// One-time read of every registered customer.
  Future<List<Map<String, String>>> fetchUsers() async {
    if (!_initialized) return const [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((d) => {
                'email': (d.data()['email'] as String?) ?? d.id,
                'name': (d.data()['name'] as String?) ?? d.id,
                'passwordHash': (d.data()['passwordHash'] as String?) ?? '',
              })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Live customer directory, so the admin tab refreshes when anyone
  /// signs up anywhere.
  Stream<List<Map<String, String>>> streamUsers() {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {
                  'email': (d.data()['email'] as String?) ?? d.id,
                  'name': (d.data()['name'] as String?) ?? d.id,
                })
            .toList());
  }

  // ════════════════════════════════════════════════════════════════
  //  Riders
  // ════════════════════════════════════════════════════════════════

  ///   riders/{riderId}
  Future<void> upsertRider(models.RiderAccount rider) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('riders').doc(rider.id).set({
        'name': rider.name,
        'email': rider.email,
        'vehicle': rider.vehicle,
        'online': rider.online,
        // Never clobber a stored hash with null — only write it when
        // this account object actually carries one.
        if (rider.passwordHash != null) 'passwordHash': rider.passwordHash,
        if (rider.lastKnownLocation != null)
          'location': GeoPoint(
            rider.lastKnownLocation!.lat,
            rider.lastKnownLocation!.lng,
          ),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// One-time pull of every rider's password hash (mirrored at register
  /// time), keyed by email — lets a rider signed up on one device log in
  /// on another.
  Future<Map<String, String>> fetchRiderPasswordHashes() async {
    if (!_initialized) return const {};
    try {
      final snap = await FirebaseFirestore.instance.collection('riders').get();
      final out = <String, String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final email = (data['email'] as String?) ?? d.id;
        final hash = data['passwordHash'] as String?;
        if (hash != null && hash.isNotEmpty) {
          out[email.trim().toLowerCase()] = hash;
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// Throttled write of a rider's latest position onto their own doc
  /// (separate from the per-order location trail).
  Future<void> pushRiderAccountLocation(
      String riderId, models.GeoPoint point) async {
    if (!_initialized) return;
    final now = DateTime.now();
    final key = 'rider:$riderId';
    final last = _lastPushAt[key];
    if (last != null && now.difference(last) < minWriteInterval) return;
    _lastPushAt[key] = now;
    try {
      await FirebaseFirestore.instance.collection('riders').doc(riderId).set({
        'location': GeoPoint(point.lat, point.lng),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Live rider registry — the admin map/list updates as riders come
  /// online and their GPS moves.
  Stream<List<models.RiderAccount>> streamRiders() {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('riders')
        .snapshots()
        .map((snap) => snap.docs.map(_riderFromDoc).toList());
  }

  models.RiderAccount _riderFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return models.RiderAccount(
      id: doc.id,
      name: (d['name'] as String?) ?? doc.id,
      email: (d['email'] as String?) ?? '',
      vehicle: (d['vehicle'] as String?) ?? 'Motorcycle',
      online: (d['online'] as bool?) ?? true,
      lastKnownLocation: _geoFrom(d['location']),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Restaurant partners
  // ════════════════════════════════════════════════════════════════

  ///   restaurants/{email}  (same doc the catalog seeder writes)
  Future<void> upsertRestaurant(models.RestaurantAccount restaurant) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurant.email)
          .set({
        'name': restaurant.name,
        'email': restaurant.email,
        'cuisine': restaurant.cuisine,
        'address': restaurant.address,
        'location': GeoPoint(
          restaurant.location.lat,
          restaurant.location.lng,
        ),
        'acceptingOrders': restaurant.acceptingOrders,
        if (restaurant.passwordHash != null)
          'passwordHash': restaurant.passwordHash,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// One-time pull of every restaurant-partner password hash, keyed by
  /// email — lets a partner signed up on one device log in on another.
  Future<Map<String, String>> fetchRestaurantPasswordHashes() async {
    if (!_initialized) return const {};
    try {
      final snap =
          await FirebaseFirestore.instance.collection('restaurants').get();
      final out = <String, String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final email = (data['email'] as String?) ?? d.id;
        final hash = data['passwordHash'] as String?;
        if (hash != null && hash.isNotEmpty) {
          out[email.trim().toLowerCase()] = hash;
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// Live restaurant-partner registry.
  Stream<List<models.RestaurantAccount>> streamRestaurants() {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('restaurants')
        .snapshots()
        .map((snap) => snap.docs.map(_restaurantFromDoc).toList());
  }

  models.RestaurantAccount _restaurantFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return models.RestaurantAccount(
      id: (d['email'] as String?) ?? doc.id,
      name: (d['name'] as String?) ?? doc.id,
      email: (d['email'] as String?) ?? '',
      cuisine: (d['cuisine'] as String?) ?? '',
      address: (d['address'] as String?) ?? '',
      location:
          _geoFrom(d['location']) ?? const models.GeoPoint(8.0660, 123.7480),
      acceptingOrders: (d['acceptingOrders'] as bool?) ?? true,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Management actions (admin, and a rider/partner on their own doc)
  // ════════════════════════════════════════════════════════════════

  /// Turns a rider on (available for new deliveries) or off.
  Future<void> setRiderOnline({
    required String riderId,
    required bool online,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('riders')
          .doc(riderId)
          .set({'online': online}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Lets a restaurant partner (or the admin) pause/resume new orders.
  Future<void> setRestaurantAccepting({
    required String restaurantEmail,
    required bool accepting,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantEmail)
          .set({'acceptingOrders': accepting}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Permanently removes an order document (admin cleanup).
  Future<void> deleteOrder(String orderId) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .delete();
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════
  //  Orders — full documents
  // ════════════════════════════════════════════════════════════════

  /// Writes the complete order document so a remote client can see the
  /// whole order (items, address, locations) the moment it is placed,
  /// not just the status.
  Future<void> pushOrder(models.DeliveryOrder order) async {
    if (!_initialized) return;
    try {
      final data = orderToMap(order);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) data['customerUid'] = uid;
      } catch (_) {}
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .set(data, SetOptions(merge: true));
      } catch (e) {
        debugPrint('pushOrder(${order.id}) failed: $e');
      }
    }

    /// Records which rider the restaurant assigned to an order.
    Future<void> assignRider({
      required String orderId,
      required models.RiderAccount rider,
    }) async {
      if (!_initialized) return;
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
          'assignedRiderId': rider.id,
          'assignedRiderName': rider.name,
          'status': models.OrderStatus.riderAssigned.name,
          'statusUpdatedAt': DateTime.now(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('assignRider($orderId) failed: $e');
      }
    }

  /// One-time read of every order (used to hydrate AppData at startup).
  Future<List<models.DeliveryOrder>> fetchOrders() async {
    if (!_initialized) return const [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('placedAt', descending: true)
          .get();
      return snap.docs.map(_orderFromDoc).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Live stream of all orders — replaces the local list in AppData so
  /// restaurant/rider/admin dashboards and customer trackers all move in
  /// real time across devices.
  Stream<List<models.DeliveryOrder>> streamAllOrders() {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  /// Orders for one restaurant partner's dashboard.
  Stream<List<models.DeliveryOrder>> streamOrdersForRestaurant(
      String restaurantName) {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantName', isEqualTo: restaurantName)
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  /// Orders currently assigned to a rider.
  Stream<List<models.DeliveryOrder>> streamOrdersForRider(String riderId) {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('assignedRiderId', isEqualTo: riderId)
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  /// Orders waiting for any rider to accept.
  Stream<List<models.DeliveryOrder>> streamAvailableForPickup() {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: models.OrderStatus.readyForPickup.name)
        .where('assignedRiderId', isNull: true)
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  /// Orders placed by one customer (order history for the profile sheet).
  Stream<List<models.DeliveryOrder>> streamOrdersForCustomer(String email) {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('customerEmail', isEqualTo: email)
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  // ════════════════════════════════════════════════════════════════
  //  Rider GPS + status-lifecycle (existing behavior, kept)
  // ════════════════════════════════════════════════════════════════

  /// Pushes a rider's GPS fix to Firestore, throttled to one write every
  /// [minWriteInterval] per order. First fix for an order always writes
  /// immediately.
  ///
  /// Writes:
  ///   - orders/{orderId}/riderLocation/{autoId}
  ///       { lat, lng, timestamp, accuracy }
  ///   - orders/{orderId}.lastRiderLocation
  ///       { lat, lng, timestamp }  (latest position, single-doc read)
  Future<void> pushRiderLocation({
    required String orderId,
    required models.GeoPoint point,
    double? accuracyMeters,
  }) async {
    if (!_initialized) return;

    final now = DateTime.now();
    final last = _lastPushAt[orderId];
    if (last != null && now.difference(last) < minWriteInterval) return;
    _lastPushAt[orderId] = now;

    final data = <String, dynamic>{
      'lat': point.lat,
      'lng': point.lng,
      'timestamp': now,
      'geopoint': GeoPoint(point.lat, point.lng),
      if (accuracyMeters != null) 'accuracy': accuracyMeters,
    };

    try {
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(orderId);

      // Location-history trail.
      await orderRef.collection('riderLocation').add(data);
      // Latest position for quick reads (customer side streams this).
      await orderRef.set({
        'lastRiderLocation': {
          'lat': point.lat,
          'lng': point.lng,
          'timestamp': now,
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline / no network / rules block us — ignore here; the demo
      // still runs on AppData.
    }
  }

  /// Creates the order document (placement time) so a remote client can
  /// start watching the same order document immediately.
  Future<void> createOrder({
    required String orderId,
    required models.OrderStatus status,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'status': status.name,
        'statusUpdatedAt': DateTime.now(),
        'createdAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline — ignore; the doc is merged into existence on first
      // status/location write instead.
    }
  }

  /// Mirrors an order status transition onto the order document so the
  /// customer/map reads the same doc and reflects it in real time.
  Future<void> syncOrderStatus({
    required String orderId,
    required models.OrderStatus status,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'status': status.name,
        'statusUpdatedAt': DateTime.now(),
        'history': FieldValue.arrayUnion([
          {'status': status.name, 'at': DateTime.now()},
        ]),
        }, SetOptions(merge: true));
      } catch (e) {
        // Keep the local UI responsive, but make permission/network
        // failures visible in logs instead of silently reverting later.
        debugPrint('syncOrderStatus($orderId) failed: $e');
      }
    }

    /// Mirrors a payment-status transition (gateway webhook / poll result)
  /// so every device sees the charge settle in real time.
  Future<void> syncPaymentStatus({
    required String orderId,
    required models.PaymentStatus paymentStatus,
    String? paymentReference,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'paymentStatus': paymentStatus.name,
        if (paymentReference != null) 'paymentReference': paymentReference,
        'paymentUpdatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline — ignore; AppData remains the source of truth.
    }
  }

  /// Streams the order document (`status` + `lastRiderLocation`) so the
  /// customer map can rebuild via a StreamBuilder every time either
  /// changes. Emits null for a missing/empty document.
  Stream<models.OrderSnapshot?> streamOrder(String orderId) {
    if (!_initialized) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return models.OrderSnapshot(
        status: models.parseOrderStatus(data['status'] as String?),
        paymentStatus:
            models.PaymentStatus.parse(data['paymentStatus'] as String?),
        riderLocation: _riderLocationFrom(data),
        restaurantLocation: _geoFrom(data['restaurantLocation']),
        customerLocation: _geoFrom(data['customerLocation']),
      );
    });
  }

  models.GeoPoint? _riderLocationFrom(Map<String, dynamic> data) {
    final loc = data['lastRiderLocation'];
    if (loc is Map<String, dynamic>) {
      return models.GeoPoint(
        (loc['lat'] as num?)?.toDouble() ?? 0,
        (loc['lng'] as num?)?.toDouble() ?? 0,
      );
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════
  //  Model ⇄ Firestore conversion helpers
  // ════════════════════════════════════════════════════════════════

  Map<String, dynamic> orderToMap(models.DeliveryOrder o) => {
        'id': o.id,
        'customerEmail': o.customerEmail,
        'customerName': o.customerName,
        'restaurantName': o.restaurantName,
        'items': o.items,
        'total': o.total,
        'deliveryAddress': o.deliveryAddress,
        'customerLocation': GeoPoint(
          o.customerLocation.lat,
          o.customerLocation.lng,
        ),
        'restaurantLocation': GeoPoint(
          o.restaurantLocation.lat,
          o.restaurantLocation.lng,
        ),
        'paymentMethod': o.paymentMethod,
        'paymentStatus': o.paymentStatus.name,
        if (o.paymentReference != null) 'paymentReference': o.paymentReference,
        'status': o.status.name,
        'placedAt': o.placedAt,
        'statusUpdatedAt': DateTime.now(),
        if (o.assignedRiderId != null) 'assignedRiderId': o.assignedRiderId,
        if (o.assignedRiderName != null)
          'assignedRiderName': o.assignedRiderName,
        if (o.riderLocation != null)
          'riderLocation': GeoPoint(
            o.riderLocation!.lat,
            o.riderLocation!.lng,
          ),
        'history': o.history
            .map((e) => {'status': e.key.name, 'at': e.value})
            .toList(),
      };

  List<models.DeliveryOrder> _ordersFromSnapshot(QuerySnapshot snap) =>
      snap.docs.map(_orderFromDoc).toList();

  models.DeliveryOrder _orderFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    final items = (d['items'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    final history = (d['history'] as List?)
            ?.whereType<Map>()
            .map((e) => MapEntry(
                  models.parseOrderStatus('${e['status']}') ??
                      models.OrderStatus.placed,
                  _dateFrom(e['at']) ?? DateTime.now(),
                ))
            .toList() ??
        const <MapEntry<models.OrderStatus, DateTime>>[];

    return models.DeliveryOrder(
      id: (d['id'] as String?) ?? doc.id,
      customerEmail: (d['customerEmail'] as String?) ?? '',
      customerName: (d['customerName'] as String?) ?? 'Customer',
      restaurantName: (d['restaurantName'] as String?) ?? '',
      items: items,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      deliveryAddress: (d['deliveryAddress'] as String?) ?? '',
      customerLocation: _geoFrom(d['customerLocation']) ??
          const models.GeoPoint(8.0650, 123.7480),
      restaurantLocation: _geoFrom(d['restaurantLocation']) ??
          const models.GeoPoint(8.0660, 123.7480),
      paymentMethod: (d['paymentMethod'] as String?) ?? 'GCash',
      status: models.parseOrderStatus(d['status'] as String?) ??
          models.OrderStatus.placed,
      paymentStatus: models.PaymentStatus.parse(d['paymentStatus'] as String?),
      paymentReference: d['paymentReference'] as String?,
      assignedRiderId: d['assignedRiderId'] as String?,
      assignedRiderName: d['assignedRiderName'] as String?,
      riderLocation: _geoFrom(d['riderLocation']),
      placedAt: _dateFrom(d['placedAt']) ?? DateTime.now(),
      history: history,
    );
  }

  models.GeoPoint? _geoFrom(Object? value) {
    if (value is GeoPoint) {
      return models.GeoPoint(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = value['lat'];
      final lng = value['lng'];
      if (lat is num && lng is num) {
        return models.GeoPoint(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
