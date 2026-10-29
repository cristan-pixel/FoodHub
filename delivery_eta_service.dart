// lib/services/delivery_eta_service.dart
//
// Computes a real, live delivery ETA for an order:
//
//   ETA = remaining restaurant prep time + routed travel time
//
// Prep time comes from the dishes in the order (the max `prep` value)
// and is counted down from the moment the order was placed, so it drops
// as the restaurant cooks. Travel time comes from OSRM via
// [RouteService], using the rider's live position once they are on the
// way, and falls back to a straight-line distance / average speed when
// routing is offline.
//
// The result is only a UI estimate — it is never written to Firestore
// and never changes the order's real status.

import 'dart:math' as math;
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/route_service.dart';

class DeliveryEta {
  /// Restaurant cooking time still left (0 once the food is ready).
  final int prepMinutes;

  /// Estimated driving time for the current leg to the customer.
  final int travelMinutes;

  /// Wall-clock time the order is expected to reach the customer.
  final DateTime arrival;

  const DeliveryEta({
    required this.prepMinutes,
    required this.travelMinutes,
    required this.arrival,
  });

  int get totalMinutes => prepMinutes + travelMinutes;
}

class DeliveryEtaService {
  DeliveryEtaService._();
  static final DeliveryEtaService instance = DeliveryEtaService._();

  /// Fallback speed used when OSRM is unreachable (~21 km/h including
  /// stops in city traffic).
  static const double _fallbackSpeedMetersPerMinute = 350;

  static const int _minTravelMinutes = 1;

  Future<DeliveryEta> estimate({
    required OrderStatus status,
    required DateTime placedAt,
    required int prepMinutes,
    required GeoPoint restaurant,
    required GeoPoint customer,
    GeoPoint? rider,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();

    if (status == OrderStatus.delivered || status == OrderStatus.cancelled) {
      return DeliveryEta(prepMinutes: 0, travelMinutes: 0, arrival: at);
    }

    final prepRemaining = _prepRemaining(status, placedAt, prepMinutes, at);

    // While the rider is carrying the food, measure from the rider's
    // live position. Before pickup (or before assignment) the whole
    // restaurant → customer leg still has to happen, so use that.
    final enRoute =
        status == OrderStatus.pickedUp || status == OrderStatus.onTheWay;
    final origin = enRoute ? (rider ?? restaurant) : restaurant;

    final route = await RouteService.instance.estimate(
      origin: origin,
      destination: customer,
    );

    final travel = route != null
        ? math.max(_minTravelMinutes, (route.duration.inSeconds / 60).ceil())
        : math.max(
            _minTravelMinutes,
            (_distanceMeters(origin, customer) / _fallbackSpeedMetersPerMinute)
                .ceil());

    return DeliveryEta(
      prepMinutes: prepRemaining,
      travelMinutes: travel,
      arrival: at.add(Duration(minutes: prepRemaining + travel)),
    );
  }

  int _prepRemaining(
    OrderStatus status,
    DateTime placedAt,
    int prepMinutes,
    DateTime now,
  ) {
    if (prepMinutes <= 0) return 0;
    switch (status) {
      case OrderStatus.placed:
      case OrderStatus.restaurantAccepted:
      case OrderStatus.preparing:
        final elapsed = now.difference(placedAt).inMinutes;
        return (prepMinutes - elapsed).clamp(0, prepMinutes);
      default:
        // Ready for pickup / rider assigned / picked up / on the way /
        // delivered / cancelled — the kitchen is no longer cooking.
        return 0;
    }
  }

  double _distanceMeters(GeoPoint a, GeoPoint b) {
    const earthRadiusMeters = 6371000.0;
    double radians(double d) => d * math.pi / 180;
    final lat1 = radians(a.lat);
    final lat2 = radians(b.lat);
    final dLat = radians(b.lat - a.lat);
    final dLng = radians(b.lng - a.lng);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
  }
}
