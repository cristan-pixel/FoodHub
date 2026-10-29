// lib/models/order_models.dart
//
// Shared data models used across the Customer, Rider, Restaurant and
// Admin sides of the app. Keeping these in one place is what lets an
// order placed by a customer show up live for a restaurant, get
// claimed by a rider, and be watched on a map by an admin — all
// backed by the same in-memory record.

import 'package:flutter/foundation.dart';

/// A simple lat/lng pair. We keep our own tiny type here so the model
/// layer doesn't have to import a map SDK directly — screens convert
/// to the map library's own `LatLng` only where they build the map.
@immutable
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  /// Linear-interpolate between two points — used to animate a rider
  /// marker smoothly between GPS updates instead of jumping.
  static GeoPoint lerp(GeoPoint a, GeoPoint b, double t) {
    return GeoPoint(
      a.lat + (b.lat - a.lat) * t,
      a.lng + (b.lng - a.lng) * t,
    );
  }

  @override
  String toString() => '($lat, $lng)';
}

/// Parses a status name (as stored in Firestore, e.g. "onTheWay") back
/// into an [OrderStatus], or null when the value is unknown/absent.
OrderStatus? parseOrderStatus(String? name) =>
    name == null ? null : OrderStatus.values.asNameMap()[name];

/// A lightweight read of a single order document in Firestore — the
/// fields the live map tracks: the current status, the rider's latest
/// position, and the order's restaurant/customer drop points, all
/// updated in real time on the same document.
@immutable
class OrderSnapshot {
  final OrderStatus? status;
  final PaymentStatus? paymentStatus;
  final GeoPoint? riderLocation;
  final GeoPoint? restaurantLocation;
  final GeoPoint? customerLocation;

  const OrderSnapshot({
    this.status,
    this.paymentStatus,
    this.riderLocation,
    this.restaurantLocation,
    this.customerLocation,
  });
}

// Enhanced enums keep `label` / `isActive` as real instance members rather
// than extension members. Extensions are resolved statically, so a value
// reached through `dynamic` (Firestore/FCM payloads, callbacks) would throw
// `NoSuchMethodError: Class 'OrderStatus' has no instance getter 'label'`.
enum OrderStatus {
  placed('Order Placed'), // customer placed the order, waiting on restaurant
  restaurantAccepted(
      'Confirmed by Restaurant'), // restaurant confirmed, not yet cooking
  preparing('Preparing'), // restaurant is cooking
  readyForPickup('Ready for Pickup'), // food ready, picking a rider
  riderAssigned('Rider Assigned'), // rider picked, heading to restaurant
  pickedUp('Picked Up'), // rider has the food
  onTheWay('On the Way'), // rider en route to customer
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderStatus(this.label);

  final String label;

  bool get isActive =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;
}

/// Payment lifecycle, kept separate from the delivery lifecycle
/// ([OrderStatus]). Cash-on-delivery orders are created already
/// [cashOnDelivery]-pending; online orders start [pending] and only flip
/// to [paid] once the gateway's webhook confirms the charge.
enum PaymentStatus {
  pending('Payment Pending'), // online checkout started, waiting
  paid('Paid'), // gateway confirmed the charge
  failed('Payment Failed'), // gateway declined / timed out
  cashOnDelivery('Cash on Delivery'); // pay the rider on arrival

  const PaymentStatus(this.label);

  final String label;

  String get storageName => name;

  static PaymentStatus? parse(String? name) =>
      name == null ? null : PaymentStatus.values.asNameMap()[name];
}

class DeliveryOrder {
  final String id;
  final String customerEmail;
  final String customerName;
  final String restaurantName;
  final List<Map<String, dynamic>> items;
  final double total;
  String deliveryAddress;
  final GeoPoint customerLocation;
  final GeoPoint restaurantLocation;
  String paymentMethod;
  OrderStatus status;
  PaymentStatus paymentStatus;

  /// Gateway reference for an online payment (Maya `checkoutId`, PayMongo
  /// `checkout_session_id`, …). Null for cash-on-delivery / demo orders.
  String? paymentReference;
  String? assignedRiderId;
  String? assignedRiderName;
  GeoPoint? riderLocation;
  final DateTime placedAt;
  final List<MapEntry<OrderStatus, DateTime>> history;

  DeliveryOrder({
    required this.id,
    required this.customerEmail,
    required this.customerName,
    required this.restaurantName,
    required this.items,
    required this.total,
    required this.deliveryAddress,
    required this.customerLocation,
    required this.restaurantLocation,
    required this.paymentMethod,
    this.status = OrderStatus.placed,
    PaymentStatus? paymentStatus,
    this.paymentReference,
    this.assignedRiderId,
    this.assignedRiderName,
    this.riderLocation,
    DateTime? placedAt,
    List<MapEntry<OrderStatus, DateTime>>? history,
  })  : paymentStatus = paymentStatus ??
            (paymentMethod == 'Cash on Delivery'
                ? PaymentStatus.cashOnDelivery
                : PaymentStatus.pending),
        placedAt = placedAt ?? DateTime.now(),
        history = history ?? [MapEntry(OrderStatus.placed, DateTime.now())];

  /// True when the order still needs an online charge to complete (an
  /// online method that the gateway has not yet confirmed).
  bool get awaitingPayment =>
      paymentStatus == PaymentStatus.pending ||
      paymentStatus == PaymentStatus.failed;

  /// True when this order is fully settled (paid online or COD).
  bool get isSettled =>
      paymentStatus == PaymentStatus.paid ||
      paymentStatus == PaymentStatus.cashOnDelivery;

  String get orderSummary {
    if (items.isEmpty) return 'Order';
    final first = items.first['name'] as String? ?? 'Item';
    return items.length == 1 ? first : '$first +${items.length - 1} more';
  }
}

class RiderAccount {
  final String id;
  final String name;
  final String email;
  final String vehicle;
  bool online;
  GeoPoint? lastKnownLocation;

  RiderAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.vehicle,
    this.online = true,
    this.lastKnownLocation,
    this.passwordHash,
  });

  /// Mirrored credential hash (written by [rider_auth_service] at register /
  /// login time and pulled from Firestore so a rider can sign in from any
  /// device). Kept on the account object so the sync service can mirror it
  /// atomically with the rest of the rider doc.
  final String? passwordHash;
}

class RestaurantAccount {
  final String id;
  final String name;
  final String email;
  final String cuisine;
  final String address;
  final GeoPoint location;
  bool acceptingOrders;

  RestaurantAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.cuisine,
    required this.address,
    required this.location,
    this.acceptingOrders = true,
    this.passwordHash,
  });

  final String? passwordHash;
}
