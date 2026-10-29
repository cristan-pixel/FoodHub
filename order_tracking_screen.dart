// lib/screens/order_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/delivery_eta_service.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/payment_service.dart';
import 'package:foodhub1/widgets/live_order_map.dart';

class OrderTrackingScreen extends StatefulWidget {
  final double totalAmount;
  final String deliveryTime;
  final String orderSummary;
  final String orderNumber;
  final String deliveryAddress;
  final String paymentMethod;

  const OrderTrackingScreen({
    super.key,
    required this.totalAmount,
    required this.deliveryTime,
    required this.orderSummary,
    required this.orderNumber,
    required this.deliveryAddress,
    required this.paymentMethod,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late TextEditingController _addressController;
  late final Stream<OrderSnapshot?> _orderStream;
  StreamSubscription<OrderSnapshot?>? _orderSub;
  OrderStatus? _streamStatus;
  PaymentStatus? _streamPaymentStatus;
  GeoPoint? _streamRiderLocation;
  GeoPoint? _streamRestaurantLocation;
  GeoPoint? _streamCustomerLocation;

  DeliveryEta? _eta;
  Timer? _etaTimer;
  bool _etaFetching = false;
  DateTime _lastEtaRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.deliveryAddress);
    AppData.instance.addListener(_onLocalOrdersChanged);
    _orderStream = FirebaseSyncService.instance.streamOrder(widget.orderNumber);
    _orderSub = _orderStream.listen((snap) {
      if (snap == null || !mounted) return;
      final statusChanged = snap.status != null && snap.status != _streamStatus;
      setState(() {
        _streamStatus = snap.status;
        _streamRiderLocation = snap.riderLocation;
        _streamRestaurantLocation = snap.restaurantLocation;
        _streamCustomerLocation = snap.customerLocation;
        if (snap.paymentStatus != null) {
          _streamPaymentStatus = snap.paymentStatus;
        }
      });
      _refreshEta(force: statusChanged);
    }, onError: (_) {
      // Offline / rules deny read — the tracker falls back to AppData.
    });
    _etaTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshEta(force: true),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEta());
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    AppData.instance.removeListener(_onLocalOrdersChanged);
    _orderSub?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  void _onLocalOrdersChanged() {
    final now = DateTime.now();
    if (now.difference(_lastEtaRefresh) < const Duration(seconds: 15)) return;
    _refreshEta();
  }

  /// Recomputes prep + travel time from the latest status/locations.
  /// Throttled so a fast-moving rider doesn't trigger a refresh storm;
  /// RouteService caches the actual road lookup.
  Future<void> _refreshEta({bool force = false}) async {
    if (!mounted || _etaFetching) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastEtaRefresh) < const Duration(seconds: 15)) {
      return;
    }
    _lastEtaRefresh = now;

    final order = AppData.instance.orderById(widget.orderNumber);
    final status = _streamStatus ?? order?.status ?? OrderStatus.placed;
    if (status == OrderStatus.delivered || status == OrderStatus.cancelled) {
      if (mounted) {
        setState(() {
          _eta = DeliveryEta(
            prepMinutes: 0,
            travelMinutes: 0,
            arrival: now,
          );
        });
      }
      return;
    }

    final restaurant = _streamRestaurantLocation ?? order?.restaurantLocation;
    final customer = _streamCustomerLocation ?? order?.customerLocation;
    if (restaurant == null || customer == null) return;
    final rider = _streamRiderLocation ?? order?.riderLocation;

    _etaFetching = true;
    try {
      final eta = await DeliveryEtaService.instance.estimate(
        status: status,
        placedAt: order?.placedAt ?? now,
        prepMinutes: _prepMinutes(order),
        restaurant: restaurant,
        customer: customer,
        rider: rider,
      );
      if (!mounted) return;
      setState(() => _eta = eta);
    } finally {
      _etaFetching = false;
    }
  }

  int _prepMinutes(DeliveryOrder? order) {
    if (order != null) {
      var max = 0;
      for (final item in order.items) {
        final prep = int.tryParse('${item['prep']}') ?? 0;
        if (prep > max) max = prep;
      }
      if (max > 0) return max;
    }
    // Fallback for the first frame / a tracker opened after restart:
    // the checkout screen passes "30 mins (Shop Prep Time)".
    final match = RegExp(r'(\d+)').firstMatch(widget.deliveryTime);
    return int.tryParse(match?.group(1) ?? '') ?? 30;
  }

  /// Maps the real order lifecycle (live Firestore status first, AppData
  /// as fallback) to the 4 visual steps, so the tracker keeps advancing
  /// even if the local store hasn't re-hydrated yet.
  int get _stepFromStatus {
    final status =
        _streamStatus ?? AppData.instance.orderById(widget.orderNumber)?.status;
    if (status == null) return 0;
    switch (status) {
      case OrderStatus.delivered:
        return 3;
      case OrderStatus.riderAssigned:
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return 2;
      case OrderStatus.readyForPickup:
        return 1;
      case OrderStatus.placed:
      case OrderStatus.restaurantAccepted:
      case OrderStatus.preparing:
        return 0;
      case OrderStatus.cancelled:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Order Tracking",
          style:
              TextStyle(color: Color(0xFF1A1D26), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Order #${widget.orderNumber}",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Order Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.orderSummary,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "\u20B1${widget.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Delivery Address Label
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          "Delivery Address",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Plain text typing field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFEE7D6)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: _addressController,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        maxLines: 2,
                        minLines: 1,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: "e.g. Purok 3, Poblacion, Tangub City",
                          hintStyle:
                              TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (value) {
                          // Address updates live as the user types
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    _buildInfoRow(
                        Icons.credit_card_outlined, widget.paymentMethod),
                    const SizedBox(height: 8),
                    _buildPaymentBadge(),
                    const Divider(height: 24, color: Color(0xFFFEE7D6)),
                    _buildEtaCard(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Live GPS tracking map ─────────────────────────────
              // Shows once AppData has this order (i.e. it went through
              // the normal checkout flow) and rebuilds live as the
              // rider's GPS location updates.
              AnimatedBuilder(
                animation: AppData.instance,
                builder: (context, _) {
                  final order = AppData.instance.orderById(widget.orderNumber);
                  // Show the tracker as long as the order exists locally
                  // OR the Firestore document is streaming (survives
                  // logout/restart before AppData re-hydrates).
                  if (order == null && _streamStatus == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_searching,
                              size: 16, color: Color(0xFFFF6600)),
                          const SizedBox(width: 6),
                          Text(
                            (_streamStatus ?? order?.status)?.label ??
                                'Order Placed',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Streams the same Firestore order document
                      // (orders/{orderId}) so the rider marker and status
                      // badge update live; falls back to in-memory AppData
                      // when Firebase is unavailable.
                      LiveOrderMap(
                        orderId: widget.orderNumber,
                        height: 200,
                        orderStream: _orderStream,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Tracking Steps — rebuild live with the real order status
              AnimatedBuilder(
                animation: AppData.instance,
                builder: (context, _) {
                  final currentStep = _stepFromStatus;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStep(
                        icon: Icons.access_time_filled,
                        title: "Preparing",
                        subtitle: "Restaurant is preparing your order",
                        stepIndex: 0,
                        currentStep: currentStep,
                      ),
                      _buildStep(
                        icon: Icons.inventory_2_outlined,
                        title: "Ready for Pickup",
                        subtitle: "Order is packed and ready",
                        stepIndex: 1,
                        currentStep: currentStep,
                      ),
                      _buildStep(
                        icon: Icons.local_shipping_outlined,
                        title: "On the Way",
                        subtitle: "Driver is heading to your address",
                        stepIndex: 2,
                        currentStep: currentStep,
                      ),
                      _buildStep(
                        icon: Icons.home_outlined,
                        title: "Delivered",
                        subtitle: "Enjoy your meal!",
                        stepIndex: 3,
                        currentStep: currentStep,
                        isLast: true,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F2F4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Close",
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Live ETA card: remaining prep time + actual routed travel time.
  Widget _buildEtaCard() {
    final order = AppData.instance.orderById(widget.orderNumber);
    final status = _streamStatus ?? order?.status ?? OrderStatus.placed;
    final eta = _eta;

    IconData icon = Icons.access_time;
    String title;
    String? subtitle;
    Color color = const Color(0xFF1A1D26);

    if (status == OrderStatus.delivered) {
      icon = Icons.check_circle;
      title = 'Delivered';
      subtitle = 'Enjoy your meal!';
    } else if (status == OrderStatus.cancelled) {
      icon = Icons.cancel_outlined;
      title = 'Order cancelled';
      color = Colors.red.shade700;
    } else if (eta == null) {
      title = 'Estimated arrival: ${widget.deliveryTime}';
      subtitle = 'Calculating live travel time…';
    } else if (eta.totalMinutes <= 0) {
      title = 'Arriving now';
      subtitle = 'Estimated arrival: ${_clock(eta.arrival)}';
    } else {
      title = 'Arriving in ~${eta.totalMinutes} min';
      subtitle = 'Estimated arrival: ${_clock(eta.arrival)}'
          ' · ${eta.prepMinutes} min prep + ${eta.travelMinutes} min travel';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFF6600)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _clock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Live payment-status pill, plus a "Pay now" button while an online
  /// charge is still pending (re-opens the hosted checkout).
  Widget _buildPaymentBadge() {
    final status = _streamPaymentStatus ??
        AppData.instance.orderById(widget.orderNumber)?.paymentStatus;
    if (status == null) return const SizedBox.shrink();

    final (color, icon) = switch (status) {
      PaymentStatus.paid => (const Color(0xFF00C566), Icons.check_circle),
      PaymentStatus.pending => (const Color(0xFFFF9800), Icons.hourglass_top),
      PaymentStatus.failed => (const Color(0xFFE53935), Icons.error_outline),
      PaymentStatus.cashOnDelivery => (
          const Color(0xFF3F51B5),
          Icons.payments_outlined
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (status == PaymentStatus.pending ||
            status == PaymentStatus.failed) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('Pay now with ${widget.paymentMethod}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6600),
                side: const BorderSide(color: Color(0xFFFF6600)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _reopenCheckout,
            ),
          ),
        ],
      ],
    );
  }

  /// Re-creates a checkout session for a still-unpaid order and reopens
  /// the hosted payment page in the browser.
  Future<void> _reopenCheckout() async {
    final order = AppData.instance.orderById(widget.orderNumber);
    final amount = order?.total ?? widget.totalAmount;
    final result = await PaymentService.instance.startCheckout(
      orderId: widget.orderNumber,
      amount: amount,
      method: widget.paymentMethod,
    );
    if (!mounted) return;
    final url = result.session?.checkoutUrl;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.message ??
          'Online payment is unavailable — please pay cash on delivery.'),
      backgroundColor: Colors.orange.shade800,
    ));
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required int stepIndex,
    required int currentStep,
    bool isLast = false,
  }) {
    final bool isCompleted = stepIndex <= currentStep;
    final bool isActive = stepIndex == currentStep;

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF00C566)
                      : const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? const Color(0xFF00C566)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.black : Colors.grey[400],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6600),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "In progress",
                          style: TextStyle(
                            color: Color(0xFFFF6600),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
