// lib/services/app_data.dart
//
// A single in-memory, app-wide store shared by every role (customer,
// rider, restaurant, admin). It's a ChangeNotifier so any screen can
// wrap itself in an AnimatedBuilder/ListenableBuilder and stay live —
// this is what makes "the restaurant sees the order the instant the
// customer places it" and "the admin map moves the instant a rider's
// GPS updates" work without a real backend.
//
// Swap this for Firestore / a REST API + websockets later; every
// screen already talks to it through this same interface.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/notification_service.dart';
import 'package:foodhub1/services/seed_data.dart';
import 'package:foodhub1/services/session_context.dart';

class AppData extends ChangeNotifier {
  AppData._internal() {
    _seed();
  }
  static final AppData instance = AppData._internal();

  final List<DeliveryOrder> _orders = [];
  final List<RiderAccount> _riders = [];
  final List<RestaurantAccount> _restaurants = [];

  List<DeliveryOrder> get orders => List.unmodifiable(_orders);
  List<RiderAccount> get riders => List.unmodifiable(_riders);
  List<RestaurantAccount> get restaurants => List.unmodifiable(_restaurants);

  int _orderCounter = 1000;

  /// Last status we observed per order id — used to raise an on-device
  /// notification when *somebody else* (the restaurant across town, the
  /// rider, another device) moves an order forward.
  final Map<String, OrderStatus> _lastKnownStatus = {};

  /// Keeps one live Firestore subscription per collection so we never
  /// double-subscribe; the streams update the in-memory lists and ping
  /// every listening screen (AnimatedBuilder) exactly like local writes.
  bool _firestoreAttached = false;
  final List<StreamSubscription<dynamic>> _firestoreSubs = [];

  void _seed() {
    // Demo restaurants/riders around Tangub City, Misamis Occidental —
    // shared with the Firestore seeder (see seed_data.dart).
    for (var i = 0; i < seedRestaurants.length; i++) {
      final s = seedRestaurants[i];
      _restaurants.add(RestaurantAccount(
        id: 'r${i + 1}',
        name: s.name,
        email: s.email,
        cuisine: s.cuisine,
        address: s.address,
        location: s.location,
      ));
    }
    for (var i = 0; i < seedRiders.length; i++) {
      final s = seedRiders[i];
      // Rider id == email so the local account and the Firestore rider
      // document (also keyed by email) always stay the same rider.
      _riders.add(RiderAccount(
        id: s.email,
        name: s.name,
        email: s.email,
        vehicle: s.vehicle,
        lastKnownLocation: s.location,
      ));
    }
  }

  /// Hydrates the in-memory store from Firestore and starts listening to
  /// live changes (orders, riders, restaurants). Call once from `main()`
  /// after Firebase is up, and again with [force] after every sign-in
  /// (the first attempt runs before anyone is authenticated, so the
  /// secured rules deny it). No-ops when the backend is not configured.
  Future<void> attachFirestoreStreams({bool force = false}) async {
    if (_firestoreAttached && !force) return;
    if (!force) _firestoreAttached = true;
    final firebase = FirebaseSyncService.instance;
    if (!firebase.isEnabled) return;

    // Rebuild from scratch when forcing: the previous listeners belong
    // to the previous (anonymous or signed-out) session.
    for (final sub in _firestoreSubs) {
      await sub.cancel();
    }
    _firestoreSubs.clear();
    _firestoreAttached = true;

    // One-time snapshot so dashboards already show data while the live
    // streams warm up.
    try {
      final fetched = await firebase.fetchOrders();
      if (fetched.isNotEmpty) {
        _orders
          ..clear()
          ..addAll(fetched);
        for (final o in fetched) {
          _lastKnownStatus.putIfAbsent(o.id, () => o.status);
        }
        notifyListeners();
      }
    } catch (_) {}

    void ignoreError(Object error) {
      // Rules denied this session or the stream dropped — the in-memory
      // store keeps serving the UI until a new session re-attaches.
      debugPrint('Firestore stream error: $error');
    }

    _firestoreSubs.add(firebase.streamAllOrders().listen((orders) {
      _reconcileOrders(orders);
      notifyListeners();
    }, onError: ignoreError));
    _firestoreSubs.add(firebase.streamRiders().listen((riders) {
      _riders
        ..clear()
        ..addAll(riders);
      notifyListeners();
    }, onError: ignoreError));
    _firestoreSubs.add(firebase.streamRestaurants().listen((restaurants) {
      _restaurants
        ..clear()
        ..addAll(restaurants);
      notifyListeners();
    }, onError: ignoreError));
  }

  /// Swaps in a fresh snapshot of every order and raises a local
  /// notification for each one whose status changed remotely.
  void _reconcileOrders(List<DeliveryOrder> incoming) {
    for (final o in incoming) {
      final previous = _lastKnownStatus[o.id];
      if (previous != null && previous != o.status) {
        _notifyStatusChange(o);
      }
      _lastKnownStatus[o.id] = o.status;
    }
    _orders
      ..clear()
      ..addAll(incoming);
  }

  /// On-device notification for an order update that came from another
  /// participant (never for the change this device just made — those go
  /// through [_setStatus], which records the status first).
  void _notifyStatusChange(DeliveryOrder order) {
    final role = SessionContext.role;
    final email = SessionContext.email;
    switch (role) {
      case SessionRole.customer:
        if (email == null || email != order.customerEmail) return;
        unawaited(NotificationService.instance.showLocal(
          'Order ${order.id}',
          order.status == OrderStatus.cancelled
              ? 'Your order was cancelled by ${order.restaurantName}.'
              : '${order.restaurantName} · ${order.status.label}',
          payload: 'order:${order.id}',
        ));
        break;
      case SessionRole.restaurant:
        if (email == null) return;
        String? restaurantName;
        for (final r in _restaurants) {
          if (r.email == email) {
            restaurantName = r.name;
            break;
          }
        }
        if (restaurantName == null || restaurantName != order.restaurantName) {
          return;
        }
        unawaited(NotificationService.instance.showLocal(
          order.status == OrderStatus.placed
              ? 'New order ${order.id}'
              : 'Order ${order.id}',
          order.status == OrderStatus.placed
              ? '${order.orderSummary} · ₱${order.total.toStringAsFixed(2)}'
              : order.status.label,
          payload: 'order:${order.id}',
        ));
        break;
      case SessionRole.rider:
        if (email == null) return;
        String? riderId;
        for (final r in _riders) {
          if (r.email == email) {
            riderId = r.id;
            break;
          }
        }
        if (riderId == null || riderId != order.assignedRiderId) return;
        unawaited(NotificationService.instance.showLocal(
          'Delivery ${order.id}',
          order.status.label,
          payload: 'order:${order.id}',
        ));
        break;
      case SessionRole.admin:
        unawaited(NotificationService.instance.showLocal(
          'Order ${order.id}',
          '${order.customerName} · ${order.status.label}',
          payload: 'order:${order.id}',
        ));
        break;
      case null:
        return;
    }
  }

  // ── Orders ──────────────────────────────────────────────────────

  DeliveryOrder placeOrder({
    required String customerEmail,
    required String customerName,
    required String restaurantName,
    required List<Map<String, dynamic>> items,
    required double total,
    required String deliveryAddress,
    required GeoPoint customerLocation,
    required String paymentMethod,
    PaymentStatus? paymentStatus,
    String? paymentReference,
  }) {
    // Resolve the restaurant record defensively: an empty local registry
    // (e.g. a Firestore stream that hasn't hydrated yet) or a name that
    // isn't in the list must never crash the checkout at `.first`.
    RestaurantAccount? restaurant;
    if (_restaurants.isNotEmpty) {
      for (final r in _restaurants) {
        if (r.name == restaurantName) {
          restaurant = r;
          break;
        }
      }
      restaurant ??= _restaurants.first;
    }
    final order = DeliveryOrder(
      id: _newOrderId(),
      customerEmail: customerEmail,
      customerName: customerName,
      restaurantName: restaurant?.name ?? restaurantName,
      items: items,
      total: total,
      deliveryAddress: deliveryAddress,
      customerLocation: customerLocation,
      restaurantLocation: restaurant?.location ??
          const GeoPoint(8.0660, 123.7480),
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentReference: paymentReference,
    );
    _orders.insert(0, order);
    _lastKnownStatus[order.id] = order.status;
    notifyListeners();
    // Persist the complete order so every remote client (restaurant,
    // rider, admin, other devices) sees it in full immediately.
    FirebaseSyncService.instance
      ..createOrder(orderId: order.id, status: order.status)
      ..pushOrder(order);
    return order;
  }

  /// Collision-proof order number: the counter keeps short sequential
  /// ids on a single device, and the timestamp suffix guarantees the id
  /// stays unique when several devices place orders at the same time.
  String _newOrderId() {
    for (var attempt = 0; attempt < 25; attempt++) {
      _orderCounter++;
      final id = 'ORD-$_orderCounter';
      if (orderById(id) == null) return id;
    }
    return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
  }

  DeliveryOrder? orderById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Applies a payment-status transition (from the gateway webhook stream
  /// or a status poll) to the local order and mirrors it to Firestore.
  void setPaymentStatus(
    String orderId,
    PaymentStatus paymentStatus, {
    String? paymentReference,
  }) {
    final o = orderById(orderId);
    if (o == null) return;
    o.paymentStatus = paymentStatus;
    if (paymentReference != null) o.paymentReference = paymentReference;
    notifyListeners();
    FirebaseSyncService.instance.syncPaymentStatus(
      orderId: orderId,
      paymentStatus: paymentStatus,
      paymentReference: paymentReference,
    );
  }

  List<DeliveryOrder> ordersForRestaurant(String restaurantName) =>
      _orders.where((o) => o.restaurantName == restaurantName).toList();

  List<DeliveryOrder> ordersForRider(String riderId) =>
      _orders.where((o) => o.assignedRiderId == riderId).toList();

  /// Orders placed by one customer — used to repopulate the customer's
  /// history drawer after a logout/login (and kept live via Firestore).
  List<DeliveryOrder> ordersForCustomer(String email) =>
      _orders.where((o) => o.customerEmail == email).toList();

  /// Orders whose food is ready but still need a rider picked (kept for
  /// reference; the restaurant now chooses the rider via [availableRiders]).
  List<DeliveryOrder> availableForPickup() => _orders
      .where((o) =>
          o.status == OrderStatus.readyForPickup && o.assignedRiderId == null)
      .toList();

  void _setStatus(DeliveryOrder order, OrderStatus status) {
    order.status = status;
    order.history.add(MapEntry(status, DateTime.now()));
    // Record it here too so the stream reconciler below doesn't treat
    // *our own* change as a remote one and raise a notification.
    _lastKnownStatus[order.id] = status;
    notifyListeners();
    // Mirror the transition to the same Firestore order document so the
    // customer's map reflects it live (or silently no-op without a
    // configured backend).
    FirebaseSyncService.instance.syncOrderStatus(
      orderId: order.id,
      status: status,
    );
  }

  void restaurantAccept(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    _setStatus(o, OrderStatus.restaurantAccepted);
  }

  void restaurantStartPreparing(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    _setStatus(o, OrderStatus.preparing);
  }

  void restaurantMarkReady(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    _setStatus(o, OrderStatus.readyForPickup);
  }

  void restaurantReject(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    _setStatus(o, OrderStatus.cancelled);
  }

  void riderClaimOrder(String orderId, RiderAccount rider) {
    final o = orderById(orderId);
    if (o == null) return;
    o.assignedRiderId = rider.id;
    o.assignedRiderName = rider.name;
    o.riderLocation = rider.lastKnownLocation ?? o.restaurantLocation;
    _setStatus(o, OrderStatus.riderAssigned);
    // Record the assignment online so other dashboards see the rider.
    FirebaseSyncService.instance.assignRider(orderId: orderId, rider: rider);
  }

  /// Riders who can take a new delivery right now: online AND not
  /// already carrying an active order. This is the exact list a
  /// restaurant sees when it picks who delivers an order.
  List<RiderAccount> availableRiders() => _riders.where((r) {
        if (!r.online) return false;
        return !_orders.any((o) =>
            o.assignedRiderId == r.id && o.status.isActive);
      }).toList();

  /// The restaurant chooses a delivery rider once the food is ready.
  void restaurantAssignRider(String orderId, String riderId) {
    final o = orderById(orderId);
    final rider = riderById(riderId);
    if (o == null || rider == null) return;
    o.assignedRiderId = rider.id;
    o.assignedRiderName = rider.name;
    o.riderLocation = rider.lastKnownLocation ?? o.restaurantLocation;
    _setStatus(o, OrderStatus.riderAssigned);
    // Record the assignment online so the rider + customer see it live.
    FirebaseSyncService.instance.assignRider(orderId: orderId, rider: rider);
  }

  void riderMarkPickedUp(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    _setStatus(o, OrderStatus.pickedUp);
  }

  void riderMarkOnTheWay(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    _setStatus(o, OrderStatus.onTheWay);
  }

  void riderMarkDelivered(String orderId) {
    final o = orderById(orderId);
    if (o == null) return;
    _setStatus(o, OrderStatus.delivered);
  }

  /// Called whenever we get a fresh GPS fix for a rider (real device
  /// location from Geolocator, or the simulator in demo mode). Updates
  /// both the rider's own record and every order currently assigned to
  /// them, then notifies every listening screen — this is the "live
  /// GPS tracking" wire.
  void updateRiderLocation(String riderId, GeoPoint point) {
    final riderIdx = _riders.indexWhere((r) => r.id == riderId);
    if (riderIdx != -1) {
      _riders[riderIdx].lastKnownLocation = point;
    }
    for (final o in _orders) {
      if (o.assignedRiderId == riderId && o.status.isActive) {
        o.riderLocation = point;
      }
    }
    notifyListeners();
    // Mirror the fix onto the rider's own account doc so the admin's
    // rider registry/map also moves live (throttled on the service side).
    FirebaseSyncService.instance.pushRiderAccountLocation(riderId, point);
  }

  // ── Riders / restaurants registry ─────────────────────────────────

  void registerRider(RiderAccount rider) {
    _riders.add(rider);
    notifyListeners();
  }

  void registerRestaurant(RestaurantAccount restaurant) {
    _restaurants.add(restaurant);
    notifyListeners();
  }

  RiderAccount? riderById(String id) {
    try {
      return _riders.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Registry edits (used by the auth services + admin dashboard) ──

  /// Swaps a rider object in place (its immutable fields — like the
  /// mirrored credential hash — changed).
  void replaceRider(RiderAccount rider) {
    final i = _riders.indexWhere((r) => r.id == rider.id);
    if (i == -1) {
      _riders.add(rider);
    } else {
      _riders[i] = rider;
    }
    notifyListeners();
  }

  /// Swaps a restaurant object in place.
  void replaceRestaurant(RestaurantAccount restaurant) {
    final i = _restaurants.indexWhere((r) => r.email == restaurant.email);
    if (i == -1) {
      _restaurants.add(restaurant);
    } else {
      _restaurants[i] = restaurant;
    }
    notifyListeners();
  }

  /// Pings every listening screen after a mutable field (rider online
  /// flag, restaurant accepting-orders flag) changed in place.
  void notifyRiderChanged(RiderAccount rider) {
    final i = _riders.indexWhere((r) => r.id == rider.id);
    if (i != -1) _riders[i] = rider;
    notifyListeners();
  }

  void notifyRestaurantChanged(RestaurantAccount restaurant) {
    final i = _restaurants.indexWhere((r) => r.email == restaurant.email);
    if (i != -1) _restaurants[i] = restaurant;
    notifyListeners();
  }

  // ── Admin management actions ─────────────────────────────────────

  /// Cancels an order from the admin console (same transition the
  /// restaurant uses when it rejects, plus the cloud write).
  void adminCancelOrder(String orderId) => restaurantReject(orderId);

  /// Removes an order everywhere: the in-memory store, every screen
  /// fed by it, and the Firestore document.
  void adminDeleteOrder(String orderId) {
    _orders.removeWhere((o) => o.id == orderId);
    _lastKnownStatus.remove(orderId);
    notifyListeners();
    FirebaseSyncService.instance.deleteOrder(orderId);
  }

  /// Admin-side rider activation switch.
  void adminSetRiderOnline(String riderId, bool online) {
    final rider = riderById(riderId);
    if (rider == null) return;
    rider.online = online;
    notifyRiderChanged(rider);
    FirebaseSyncService.instance.setRiderOnline(riderId: riderId, online: online);
  }

  /// Admin-side restaurant pause/resume switch.
  void adminSetRestaurantAccepting(String restaurantEmail, bool accepting) {
    RestaurantAccount? restaurant;
    for (final r in _restaurants) {
      if (r.email == restaurantEmail) {
        restaurant = r;
        break;
      }
    }
    if (restaurant == null) return;
    restaurant.acceptingOrders = accepting;
    notifyRestaurantChanged(restaurant);
    FirebaseSyncService.instance.setRestaurantAccepting(
      restaurantEmail: restaurantEmail,
      accepting: accepting,
    );
  }

  // ── Admin-facing aggregates ────────────────────────────────────

  int get activeOrderCount => _orders.where((o) => o.status.isActive).length;
  int get deliveredTodayCount {
    final now = DateTime.now();
    return _orders
        .where((o) =>
            o.status == OrderStatus.delivered &&
            o.placedAt.year == now.year &&
            o.placedAt.month == now.month &&
            o.placedAt.day == now.day)
        .length;
  }
  double get totalRevenue =>
      _orders.fold(0.0, (sum, o) => sum + (o.status == OrderStatus.cancelled ? 0 : o.total));

  // ── Per-restaurant analytics (earnings + sold menu items) ─────────

  List<DeliveryOrder> ordersForRestaurantCompleted(String restaurantName) =>
      _orders
          .where((o) =>
              o.restaurantName == restaurantName &&
              o.status != OrderStatus.cancelled)
          .toList();

  /// Total revenue (not cancelled) for a given restaurant.
  double restaurantRevenue(String restaurantName) => ordersForRestaurantCompleted(
          restaurantName)
      .fold(0.0, (sum, o) => sum + o.total);

  /// Number of non-cancelled orders a restaurant has received.
  int restaurantOrderCount(String restaurantName) =>
      ordersForRestaurantCompleted(restaurantName).length;

  /// Aggregates every line item across a restaurant's non-cancelled
  /// orders into a name → total-qty-sold map, so the dashboard can show
  /// exactly which menu dishes were sold and how many times.
  Map<String, int> restaurantSoldItems(String restaurantName) {
    final counts = <String, int>{};
    final completed = ordersForRestaurantCompleted(restaurantName);
    for (final o in completed) {
      for (final item in o.items) {
        final name = (item['name'] as String?) ?? 'Unknown item';
        final qty = (item['qty'] as num?)?.toInt() ?? 1;
        counts[name] = (counts[name] ?? 0) + qty;
      }
    }
    return counts;
  }
}
