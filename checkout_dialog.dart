// lib/widgets/checkout_dialog.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:foodhub1/order_tracking_screen.dart';
import 'package:foodhub1/auth_service.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/location_service.dart';
import 'package:foodhub1/services/payment_service.dart';

// Fallback drop point used when we can't get a real GPS fix for the
// customer (e.g. desktop testing, permission denied) — same demo city
// center used to seed the restaurants in AppData (Tangub City).
const _fallbackCustomerLocation = GeoPoint(8.0650, 123.7480);

class CheckoutDialog extends StatefulWidget {
  final VoidCallback onOrderPlaced;
  final double totalAmount;
  final String currentAddress;
  final String deliveryTime;
  final String currentPayment;
  final List<Map<String, dynamic>> cartItems;
  final Function(String) onUpdateAddress;
  final Function(String) onUpdatePayment;

  const CheckoutDialog({
    super.key,
    required this.onOrderPlaced,
    required this.totalAmount,
    required this.currentAddress,
    required this.deliveryTime,
    required this.currentPayment,
    required this.cartItems,
    required this.onUpdateAddress,
    required this.onUpdatePayment,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  late TextEditingController _addressController;
  // FIX: track selected payment locally so the UI rebuilds on change
  late String _selectedPayment;
  // Blocks double-tapping Place Order while the async placement is running
  // (a second run would hit an already-cleared cart and crash with
  // "Bad state: No element" in the onOrderPlaced callback).
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.currentAddress);
    _selectedPayment = widget.currentPayment;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Checkout",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 20),

              // ── Delivery Address ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFFFE0CC), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          color: Color(0xFFFF6600), size: 20),
                      const SizedBox(width: 8),
                      const Text("Delivery Address",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
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
                        onChanged: (value) => widget.onUpdateAddress(value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Delivery Time (read-only) ─────────────────────────
              _card(Icons.access_time, Colors.black, "Delivery Time",
                  widget.deliveryTime, false, null, true),
              const SizedBox(height: 16),

              // ── Payment Method (picker) ───────────────────────────
              // FIX: now shows _selectedPayment (local state) so it updates instantly
              _card(Icons.credit_card_outlined, Colors.black, "Payment Method",
                  _selectedPayment, false, () {
                _showPicker(
                  "Payment Method",
                  [
                    "GCash",
                    "PayMaya",
                    "Credit / Debit Card",
                    "Cash on Delivery",
                  ],
                  (chosen) {
                    setState(() => _selectedPayment = chosen);
                    widget.onUpdatePayment(chosen);
                  },
                );
              }),
              const SizedBox(height: 24),

              // ── Total ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text("Total Amount",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      "\u20B1${widget.totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF6600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Place Order button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _placing ? null : _placeOrder,
                  child: _placing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text("Place Order",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    if (widget.cartItems.isEmpty) return;

    // Online checkout is tied to a Firebase account: the Cloud Function
    // verifies that the order belongs to the caller before charging it.
    if (PaymentService.instance.requiresOnlinePayment(_selectedPayment) &&
        !AuthService.instance.isLoggedIn) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign in to pay online'),
          content: const Text(
              'GCash, Maya and card payments need a FoodHub account. '
              'You can also choose Cash on Delivery.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    setState(() => _placing = true);
    final itemNames = widget.cartItems.map((e) => e['name'] as String).toList();
    final orderSummary = itemNames.length == 1
        ? itemNames.first
        : "${itemNames.first} + ${itemNames.length - 1} more";

    final typedAddress = _addressController.text.trim().isEmpty
        ? widget.currentAddress
        : _addressController.text.trim();

    // Try to use the customer's real GPS location for the drop pin so
    // riders/restaurant/admin see an accurate spot on the map; fall
    // back to a fixed demo location if GPS isn't available.
    //
    // If the GPS fix is implausibly far from the delivery area, use the
    // demo drop point instead — otherwise the tracking map auto-fits
    // two far-apart points and zooms out to span the whole region.
    final gps = await LocationService.instance.getCurrentLocation();
    final customerLocation =
        (gps != null && _kmBetween(gps, _fallbackCustomerLocation) <= 50)
            ? gps
            : _fallbackCustomerLocation;

    // Split a multi-restaurant cart into one order per restaurant so
    // EVERY partner dashboard receives its own part at the same time.
    final byRestaurant = <String, List<Map<String, dynamic>>>{};
    for (final item in widget.cartItems) {
      final rName = (item['restaurant_name'] as String?) ??
          (item['name'] as String? ?? '');
      byRestaurant.putIfAbsent(rName, () => []).add(item);
    }

    // A partner can pause incoming orders from their dashboard — refuse
    // checkout instead of creating orders the kitchen will never see.
    final paused = AppData.instance.restaurants
        .where((r) => !r.acceptingOrders)
        .map((r) => r.name)
        .toSet();
    final blocked = byRestaurant.keys.where(paused.contains).toList();
    if (blocked.isNotEmpty) {
      setState(() => _placing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${blocked.join(', ')} is not accepting orders right now. '
                'Please remove its items or try again later.'),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    // Mirror the cart-footer math (subtotal + 8% tax + shared delivery
    // fee) so the per-restaurant orders sum back to the shown total.
    const deliveryFee = 3.99;
    final cartSubtotal = _subtotal(widget.cartItems);

    final created = <DeliveryOrder>[];
    byRestaurant.forEach((rName, items) {
      final groupSubtotal = _subtotal(items);
      final feeShare =
          cartSubtotal > 0 ? deliveryFee * (groupSubtotal / cartSubtotal) : 0.0;
      final total = groupSubtotal + groupSubtotal * 0.08 + feeShare;
      created.add(AppData.instance.placeOrder(
        customerEmail: AuthService.instance.currentEmail ?? 'guest@foodhub.com',
        customerName: AuthService.instance.currentName ?? 'Guest',
        restaurantName: rName,
        items: items,
        total: total,
        deliveryAddress: typedAddress,
        customerLocation: customerLocation,
        paymentMethod: _selectedPayment,
        paymentStatus:
            PaymentService.instance.initialStatusFor(_selectedPayment),
      ));
    });

    if (created.isEmpty) {
      setState(() => _placing = false);
      return;
    }

    // Online methods: create a hosted checkout on the first order and open
    // it in the browser so the customer can actually pay. COD orders skip
    // this. If the gateway isn't configured, we surface the message and the
    // order stays "Payment Pending" (payable cash on delivery).
    final checkoutMsg = await _startOnlineCheckoutIfNeeded(created.first);

    if (!mounted) return;

    widget.onOrderPlaced();
    Navigator.pop(context); // close checkout dialog

    if (checkoutMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(checkoutMsg),
        backgroundColor: Colors.orange.shade800,
      ));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(
          totalAmount: widget.totalAmount,
          deliveryTime: widget.deliveryTime,
          orderSummary: orderSummary,
          orderNumber: created.first.id,
          deliveryAddress: typedAddress,
          // FIX: use the locally tracked payment method
          paymentMethod: _selectedPayment,
        ),
      ),
    );
  }

  /// Starts a hosted checkout for online methods and opens it in the
  /// browser. Returns a user-facing message when something needs to be said
  /// (not configured / failed), or null on success / COD.
  Future<String?> _startOnlineCheckoutIfNeeded(DeliveryOrder order) async {
    final payment = PaymentService.instance;
    if (!payment.requiresOnlinePayment(order.paymentMethod)) return null;

    final result = await payment.startCheckout(
      orderId: order.id,
      amount: order.total,
      method: order.paymentMethod,
    );

    switch (result.outcome) {
      case CheckoutOutcome.notRequired:
        return null;
      case CheckoutOutcome.awaitingPayment:
        final url = result.session?.checkoutUrl;
        if (url == null || url.isEmpty) return null;
        try {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          return 'Could not open the payment page. Copy this link to pay: $url';
        }
        return 'Complete your ${order.paymentMethod} payment in the browser.';
      case CheckoutOutcome.notConfigured:
      case CheckoutOutcome.failed:
        return result.message ??
            'Online payment is unavailable right now — your order is saved.';
    }
  }

  double _subtotal(List<Map<String, dynamic>> items) {
    double sum = 0;
    for (final i in items) {
      final price = double.tryParse(i['price']?.toString() ?? '') ?? 0.0;
      final qty = (i['qty'] as num?)?.toInt() ?? 1;
      sum += price * qty;
    }
    return sum;
  }

  double _kmBetween(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;
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
    return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
  }

  void _showPicker(String title, List<String> opts, Function(String) onSet) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10)),
          ),
          Text("Select $title",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...opts.map((o) => ListTile(
                leading: Icon(
                  o == 'GCash' || o == 'PayMaya'
                      ? Icons.account_balance_wallet_outlined
                      : o == 'Cash on Delivery'
                          ? Icons.money_outlined
                          : Icons.credit_card_outlined,
                  color: const Color(0xFFFF6600),
                ),
                title: Text(o,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: _selectedPayment == o
                    ? const Icon(Icons.check_circle, color: Color(0xFFFF6600))
                    : null,
                onTap: () {
                  onSet(o);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _card(IconData icon, Color iCol, String label, String val, bool high,
      VoidCallback? onTap,
      [bool isTime = false]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: high
              ? Border.all(color: const Color(0xFFFFE0CC), width: 1.5)
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: iCol, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(val,
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis)),
                if (!isTime) const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
