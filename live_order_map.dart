// lib/widgets/live_order_map.dart
//
// A live order-tracking map built with FlutterMap + OpenStreetMap tiles
// (no Google Maps API key required — works on Android, iOS, web and
// desktop). It plots a restaurant marker, a customer marker, and (if
// assigned) a live rider marker for a single order — rebuilding
// automatically whenever AppData notifies (i.e. whenever a new GPS fix
// comes in). The camera is kept fitted so both the delivery address and
// the rider's current position stay in view at all times.
//
// The line between the rider and the restaurant/customer is fetched as a
// real driving route via RouteService (free OSRM API) and drawn as a
// polyline; until the route arrives (or when offline) a straight-line
// approximation is used instead.
//
// Used by the customer's order-tracking screen, the rider's delivery
// screen, and the restaurant dashboard.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:foodhub1/models/order_models.dart' as models;
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/route_service.dart';
import 'package:latlong2/latlong.dart';

class LiveOrderMap extends StatefulWidget {
  final String orderId;
  final double height;

  /// When provided the widget listens to this Firestore order-document
  /// stream for the live rider position and current status
  /// (orders/{orderId}: lastRiderLocation + status), repainting the
  /// marker and status badge as they change. Falls back to AppData.
  final Stream<models.OrderSnapshot?>? orderStream;

  const LiveOrderMap({
    super.key,
    required this.orderId,
    this.height = 260,
    this.orderStream,
  });

  @override
  State<LiveOrderMap> createState() => _LiveOrderMapState();
}

class _LiveOrderMapState extends State<LiveOrderMap> {
  final MapController _controller = MapController();
  bool _mapReady = false;
  LatLngBounds? _fitted;
  StreamSubscription<models.OrderSnapshot?>? _orderSub;
  models.GeoPoint? _streamRiderLocation;
  models.GeoPoint? _streamRestaurantLocation;
  models.GeoPoint? _streamCustomerLocation;
  models.OrderStatus? _streamStatus;

  // Road-route legs (rider → restaurant / rider → customer), fetched
  // from OSRM and rebuilt as the rider advances.
  List<models.GeoPoint>? _routeToRestaurant;
  List<models.GeoPoint>? _routeToCustomer;
  models.GeoPoint? _lastRoutedRider;
  DateTime? _lastRouteFetchAt;
  bool _routeFetching = false;

  /// How many degrees of change the bounds may move before the camera
  /// re-centers. Keeps tiny GPS jitter from fighting the user's panning.
  static const double _fitTolerance = 0.0005;

  /// Re-route only after the rider has advanced by this much on the
  /// current leg, and at most once every [routeThrottle].
  static const double _reRouteDistanceMeters = 150;
  static const Duration routeThrottle = Duration(seconds: 10);

  LatLng _toLatLng(models.GeoPoint p) => LatLng(p.lat, p.lng);

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
    _listenToOrderStream();
  }

  @override
  void didUpdateWidget(LiveOrderMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderStream != widget.orderStream) {
      _listenToOrderStream();
    }
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    _orderSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _listenToOrderStream() {
    _orderSub?.cancel();
    final stream = widget.orderStream;
    if (stream == null) return;
    _orderSub = stream.listen((snapshot) {
      if (snapshot == null) return;
      setState(() {
        _streamRiderLocation = snapshot.riderLocation;
        _streamRestaurantLocation = snapshot.restaurantLocation;
        _streamCustomerLocation = snapshot.customerLocation;
        _streamStatus = snapshot.status;
      });
      _fitTo(_allPoints());
      _maybeFetchRoutes();
    }, onError: (_) {
      // Firestore offline / rules deny read — keep showing AppData.
    });
  }

  /// Fires whenever AppData changes anywhere in the app (a new GPS fix
  /// from the rider, an order status change, ...). On the customer side
  /// without a Firestore stream this is what keeps the route fresh.
  void _onAppDataChanged() {
    if (_streamRiderLocation == null) _maybeFetchRoutes();
  }

  /// Fetches fresh road routes while the rider is moving. Throttled so a
  /// moving rider only triggers a re-route every so often instead of on
  /// every GPS fix.
  Future<void> _maybeFetchRoutes() async {
    final rider = _effectiveRiderLocation();
    final order = AppData.instance.orderById(widget.orderId);
    if (rider == null || order == null || _routeFetching) return;

    if (_lastRoutedRider != null &&
        !_movedEnough(_lastRoutedRider!, rider)) {
      return;
    }
    final now = DateTime.now();
    if (_lastRouteFetchAt != null &&
        now.difference(_lastRouteFetchAt!) < routeThrottle) {
      return;
    }
    _lastRoutedRider = rider;
    _lastRouteFetchAt = now;
    _routeFetching = true;

    final restaurantFuture = RouteService.instance.route(
      origin: rider,
      destination: order.restaurantLocation,
    );
    final customerFuture = RouteService.instance.route(
      origin: rider,
      destination: order.customerLocation,
    );
    final toRestaurant = await restaurantFuture;
    final toCustomer = await customerFuture;
    _routeFetching = false;

    if (!mounted) return;
    setState(() {
      _routeToRestaurant = toRestaurant;
      _routeToCustomer = toCustomer;
    });
    _fitTo(_allPoints());
    _maybeFetchRoutes(); // catch up if the rider moved while fetching
  }

  bool _movedEnough(models.GeoPoint a, models.GeoPoint b) {
    const earthRadiusMeters = 6371000.0;
    double radians(double d) => d * math.pi / 180;
    final lat1 = radians(a.lat);
    final lat2 = radians(b.lat);
    final dLat = lat2 - lat1;
    final dLng = radians(b.lng) - radians(a.lng);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final meters = 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
    return meters >= _reRouteDistanceMeters;
  }

  List<LatLng> _allPoints() {
    final rider = _effectiveRiderLocation();
    final order = AppData.instance.orderById(widget.orderId);
    return [
      if (order != null) ...[
        _toLatLng(order.restaurantLocation),
        _toLatLng(order.customerLocation),
      ] else ...[
        if (_streamRestaurantLocation != null)
          _toLatLng(_streamRestaurantLocation!),
        if (_streamCustomerLocation != null) _toLatLng(_streamCustomerLocation!),
      ],
      if (rider != null) _toLatLng(rider),
    ];
  }

  /// Prefers the live Firestore position when subscribed; otherwise
  /// falls back to the in-memory AppData position.
  models.GeoPoint? _effectiveRiderLocation() {
    if (_streamRiderLocation != null) return _streamRiderLocation;
    final order = AppData.instance.orderById(widget.orderId);
    return order?.riderLocation;
  }

  bool _basicallySame(LatLngBounds a, LatLngBounds b) =>
      (a.north - b.north).abs() < _fitTolerance &&
      (a.south - b.south).abs() < _fitTolerance &&
      (a.east - b.east).abs() < _fitTolerance &&
      (a.west - b.west).abs() < _fitTolerance;

  void _fitTo(List<LatLng> points) {
    if (points.isEmpty || !_mapReady) return;
    final bounds = LatLngBounds.fromPoints(points);
    if (_fitted != null && _basicallySame(bounds, _fitted!)) return;
    _fitted = bounds;
    // fitCamera must run outside the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _controller.fitCamera(CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(32),
        maxZoom: 17,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final order = AppData.instance.orderById(widget.orderId);
        // Fall back to the Firestore order-document snapshot so the map
        // keeps working even after a logout/restart before AppData has
        // re-hydrated the local store.
        final restaurantLoc =
            order?.restaurantLocation ?? _streamRestaurantLocation;
        final customerLoc = order?.customerLocation ?? _streamCustomerLocation;
        if (restaurantLoc == null || customerLoc == null) {
          return SizedBox(
            height: widget.height,
            child: const Center(child: Text('Order not found')),
          );
        }

        final rider = _effectiveRiderLocation();
        final status =
            _streamStatus ?? order?.status ?? models.OrderStatus.placed;
        final waitingForRider =
            rider == null && status != models.OrderStatus.delivered;
        final points = [
          _toLatLng(restaurantLoc),
          _toLatLng(customerLoc),
          if (rider != null) _toLatLng(rider),
        ];
        _fitTo(_allPoints());

        final markers = <Marker>[
          Marker(
            point: _toLatLng(restaurantLoc),
            width: 80,
            height: 72,
            child: _labelledPin(const Color(0xFFFF6600),
                Icons.storefront_outlined, order?.restaurantName ?? 'Restaurant'),
          ),
          Marker(
            point: _toLatLng(customerLoc),
            width: 80,
            height: 72,
            child: _labelledPin(
                const Color(0xFF1E88E5), Icons.home_outlined, 'You'),
          ),
          if (rider != null)
            Marker(
              point: _toLatLng(rider),
              width: 80,
              height: 72,
              child: _labelledPin(const Color(0xFF00C566), Icons.bolt,
                  'Rider', isLive: true),
            ),
        ];

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 13,
                    initialCameraFit: CameraFit.coordinates(
                      coordinates: points,
                      padding: const EdgeInsets.all(32),
                      maxZoom: 17,
                    ),
                    onMapReady: () {
                      _mapReady = true;
                      _fitTo(_allPoints());
                    },
                    backgroundColor: const Color(0xFFE8EAED),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.foodhub.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        // Real road routes once fetched; the straight-line
                        // approximation is only a fallback while a route
                        // is loading or unavailable.
                        if (_routeToRestaurant != null &&
                            _routeToRestaurant!.length >= 2)
                          Polyline(
                            points:
                                _routeToRestaurant!.map(_toLatLng).toList(),
                            strokeWidth: 3,
                            color: const Color(0xFFFF6600),
                          ),
                        if (_routeToCustomer != null &&
                            _routeToCustomer!.length >= 2)
                          Polyline(
                            points: _routeToCustomer!.map(_toLatLng).toList(),
                            strokeWidth: 3,
                            color: const Color(0xFFFF6600),
                          ),
                        if (_routeToRestaurant == null &&
                            _routeToCustomer == null)
                          Polyline(
                            points: [
                              _toLatLng(restaurantLoc),
                              if (rider != null) _toLatLng(rider),
                              _toLatLng(customerLoc),
                            ],
                            strokeWidth: 3,
                            color: const Color(0xFFFF6600),
                          ),
                      ],
                    ),
                    MarkerLayer(markers: markers),
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
                    ),
                  ],
                ),
                // Live status badge (from the order document / AppData).
                Positioned(top: 8, left: 8, child: _statusChip(status)),
                // Distance overlay: restaurant↔customer, plus live
                // rider↔customer once a rider is on the way.
                Positioned(bottom: 8, left: 8,
                    child: _distanceChip(
                        restaurantPoint: restaurantLoc,
                        customerPoint: customerLoc,
                        rider: rider)),
                // No rider position yet — tell the user instead of
                // showing a map with a missing, unnamed marker.
                if (waitingForRider)
                  Positioned.fill(child: Center(child: _waitingPill())),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(models.OrderStatus status) {
    switch (status) {
      case models.OrderStatus.delivered:
        return const Color(0xFF1E88E5);
      case models.OrderStatus.cancelled:
        return const Color(0xFFE53935);
      case models.OrderStatus.riderAssigned:
      case models.OrderStatus.pickedUp:
      case models.OrderStatus.onTheWay:
        return const Color(0xFF00C566);
      default:
        return const Color(0xFFFF6600);
    }
  }

  Widget _statusChip(models.OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _statusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Waiting for rider location…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelledPin(Color color, IconData icon, String label,
      {bool isLive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pin(color, icon, isLive: isLive),
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(maxWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D26))),
        ),
      ],
    );
  }

  /// Shows how far the restaurant is from the customer, and — once a
  /// rider is moving — how far the rider is from the customer, so the
  /// orange line on the map has a live distance readout.
  Widget _distanceChip({
    required models.GeoPoint restaurantPoint,
    required models.GeoPoint customerPoint,
    required models.GeoPoint? rider,
  }) {
    final lines = <String>[
      'Restaurant → You: '
          '${_distanceLabel(restaurantPoint, customerPoint)} away',
    ];
    if (rider != null) {
      lines.add('Rider → You: '
          '${_distanceLabel(rider, customerPoint)} '
          '${_streamStatus == models.OrderStatus.onTheWay ? '· on the way' : ''}');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(l,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D26))),
                ))
            .toList(),
      ),
    );
  }

  String _distanceLabel(models.GeoPoint a, models.GeoPoint b) {
    final m = _distanceMeters(a, b);
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  double _distanceMeters(models.GeoPoint a, models.GeoPoint b) {
    const earthRadiusMeters = 6371000.0;
    double radians(double d) => d * math.pi / 180;
    final lat1 = radians(a.lat);
    final lat2 = radians(b.lat);
    final dLat = radians(b.lat - a.lat);
    final dLng = radians(b.lng - a.lng);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
  }

  Widget _pin(Color color, IconData icon, {bool isLive = false}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          if (isLive)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}