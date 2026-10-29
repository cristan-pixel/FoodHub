// lib/screens/rider/rider_delivery_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/location_service.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/rider_auth_service.dart';
import 'package:foodhub1/services/rider_earnings.dart';
import 'package:foodhub1/widgets/live_order_map.dart';

/// Shown once the restaurant assigns an order to the rider. Streams the
/// rider's real device GPS (via LocationService/Geolocator) into AppData
/// for as long as the delivery is active, so the customer, restaurant
/// and admin maps all move live. Also drives the order through
/// pickedUp → onTheWay → delivered.
class RiderDeliveryScreen extends StatefulWidget {
  final String orderId;
  const RiderDeliveryScreen({super.key, required this.orderId});

  @override
  State<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends State<RiderDeliveryScreen> {
  StreamSubscription<GeoPoint>? _gpsSub;
  Timer? _fallbackTimer;
  String? _locationError;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _startTrackingGps();
  }

  Future<void> _startTrackingGps() async {
    final rider = RiderAuthService.instance.currentRider;
    if (rider == null) return;

    final result = await LocationService.instance.requestPermission();
    if (!result.granted) {
      // No GPS available (permission denied, location services off, or
      // running on an emulator/desktop with no location fix) — fall
      // back to a gentle simulated walk from the restaurant toward the
      // customer so the map still demonstrates live tracking.
      _simulateWithMessage(result);
      return;
    }

    try {
      _gpsSub = LocationService.instance.watchLocation().listen(
        (point) {
          AppData.instance.updateRiderLocation(rider.id, point);
          // Mirror every GPS fix to Firestore (throttled on the service
          // side) so any backend consumer can track the rider live.
          FirebaseSyncService.instance.pushRiderLocation(
            orderId: widget.orderId,
            point: point,
          );
        },
        onError: (Object e) {
          // GPS dropped mid-delivery — switch to the simulated walk so
          // the map never freezes on a blank position.
          if (!mounted) return;
          _gpsSub?.cancel();
          _simulateWithMessage(const LocationPermissionResult(
            granted: false,
            message: 'GPS signal lost. Showing a simulated route instead.',
          ));
        },
      );
    } catch (_) {
      _simulateWithMessage(const LocationPermissionResult(
        granted: false,
        message: 'Unable to access location. Showing a simulated route.',
      ));
    }
  }

  void _simulateWithMessage(LocationPermissionResult result) {
    if (!mounted) return;
    final rider = RiderAuthService.instance.currentRider;
    if (rider == null) return;
    setState(() {
      _locationError = result.message;
      _permanentlyDenied = result.permanentlyDenied;
    });
    _simulateMovementFallback(rider.id);
  }

  void _simulateMovementFallback(String riderId) {
    _fallbackTimer?.cancel();
    final order = AppData.instance.orderById(widget.orderId);
    if (order == null) return;
    final start = order.riderLocation ?? order.restaurantLocation;
    final end = order.customerLocation;
    var t = 0.0;
    _fallbackTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || t >= 1.0) {
        timer.cancel();
        return;
      }
      t += 0.05;
      final point = GeoPoint.lerp(start, end, t);
      AppData.instance.updateRiderLocation(riderId, point);
      FirebaseSyncService.instance.pushRiderLocation(
        orderId: widget.orderId,
        point: point,
      );
    });
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderId),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: AppData.instance,
        builder: (context, _) {
          final order = AppData.instance.orderById(widget.orderId);
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_locationError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationError!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.brown),
                        ),
                        if (_permanentlyDenied)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  LocationService.instance.openSettings(),
                              child: const Text('Open Settings',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),
                LiveOrderMap(orderId: order.id, height: 260),
                const SizedBox(height: 16),
                Text(order.status.label,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF6600))),
                const SizedBox(height: 8),
                _infoRow(Icons.storefront_outlined, order.restaurantName),
                _infoRow(Icons.location_on_outlined, order.deliveryAddress),
                _infoRow(Icons.receipt_long_outlined,
                    '${order.orderSummary} · \u20B1${order.total.toStringAsFixed(2)}'),
                _earningsCard(order),
                const SizedBox(height: 20),
                _statusActions(order),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _earningsCard(DeliveryOrder order) {
    final food = RiderEarnings.foodSubtotal(order);
    final amount = RiderEarnings.amountFor(order);

    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight:
                          bold ? FontWeight.w700 : FontWeight.w400)),
              Text(value,
                  style: TextStyle(
                      fontSize: bold ? 18 : 13,
                      color: bold ? const Color(0xFF047857) : Colors.black87,
                      fontWeight:
                          bold ? FontWeight.w900 : FontWeight.w500)),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, size: 20, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Text('Your earnings',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
            ],
          ),
          const SizedBox(height: 10),
          row('Food price', '\u20B1${food.toStringAsFixed(2)}'),
          row('Rider share', RiderEarnings.percentLabel),
          const Divider(height: 18),
          row('You receive', '\u20B1${amount.toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }

  Widget _statusActions(DeliveryOrder order) {
    Widget button(String label, VoidCallback onTap) => SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onTap,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );

    switch (order.status) {
      case OrderStatus.riderAssigned:
        return button('Mark as Picked Up',
            () => AppData.instance.riderMarkPickedUp(order.id));
      case OrderStatus.pickedUp:
        return button('Start Delivery (On the Way)',
            () => AppData.instance.riderMarkOnTheWay(order.id));
      case OrderStatus.onTheWay:
        return button('Mark as Delivered', () {
          AppData.instance.riderMarkDelivered(order.id);
          Navigator.of(context).pop();
        });
      default:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F2F4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('This order is ${order.status.label.toLowerCase()}.'),
        );
    }
  }
}
