// lib/screens/rider/rider_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/rider_auth_service.dart';
import 'package:foodhub1/services/rider_earnings.dart';
import 'package:foodhub1/screens/rider/rider_delivery_screen.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rider = RiderAuthService.instance.currentRider;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Expanded(
              child: Text('Hi, ${rider?.name.split(' ').first ?? 'Rider'} 👋',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            // Availability switch: when off, restaurants can no longer
            // assign new deliveries to this rider (persisted to the cloud).
            _availabilitySwitch(rider?.online ?? false),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await RiderAuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                  '/role-select', (route) => false);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6600),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6600),
          tabs: const [
            Tab(text: 'Active Jobs'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: AppData.instance,
        builder: (context, _) {
          final mine = rider == null
              ? <DeliveryOrder>[]
              : AppData.instance.ordersForRider(rider.id);
          final active =
              mine.where((o) => o.status.isActive).toList();
          final history =
              mine.where((o) => !o.status.isActive).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              Column(
                children: [
                  if (rider != null && !rider.online) _offlineBanner(),
                  Expanded(
                    child: _orderList(
                      active,
                      emptyText: rider != null && !rider.online
                          ? 'You are offline. Switch to Online to receive '
                              'new delivery requests.'
                          : 'No deliveries assigned to you yet.\n'
                              'The restaurant will assign you an order once the food is ready.',
                      builder: (o) => _jobCard(o, isHistory: false),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  _earningsSummary(history),
                  Expanded(
                    child: _orderList(
                      history,
                      emptyText: 'No completed deliveries yet.',
                      builder: (o) => _jobCard(o, isHistory: true),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _availabilitySwitch(bool online) {
    return Tooltip(
      message: online
          ? 'Online — restaurants can assign you deliveries'
          : 'Offline — new deliveries are paused',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: online ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Switch(
            value: online,
            activeTrackColor: Colors.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: RiderAuthService.instance.setOnline,
          ),
        ],
      ),
    );
  }

  Widget _offlineBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.visibility_off_outlined, size: 16, color: Color(0xFFFF6600)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline — restaurants cannot assign you new deliveries.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A4B00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderList(
    List<DeliveryOrder> orders, {
    required String emptyText,
    required Widget Function(DeliveryOrder) builder,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Text(emptyText,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => builder(orders[i]),
    );
  }

  Widget _earningsSummary(List<DeliveryOrder> history) {
    final delivered =
        history.where((o) => o.status == OrderStatus.delivered).toList();
    final now = DateTime.now();
    final today = delivered
        .where((o) => RiderEarnings.isSameDay(
            RiderEarnings.deliveredAt(o), now))
        .toList();
    final total = delivered.fold<double>(
        0, (sum, o) => sum + RiderEarnings.amountFor(o));
    final todayTotal = today.fold<double>(
        0, (sum, o) => sum + RiderEarnings.amountFor(o));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6600), Color(0xFFFF8A3D)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's earnings",
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('\u20B1${todayTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Text(
                  'All-time \u20B1${total.toStringAsFixed(2)} \u00B7 '
                  '${RiderEarnings.percentLabel} of food price',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${today.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Text('today',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earningRow(DeliveryOrder o) {
    final food = RiderEarnings.foodSubtotal(o);
    final amount = RiderEarnings.amountFor(o);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined,
              size: 16, color: Color(0xFF047857)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your earnings \u00B7 ${RiderEarnings.percentLabel} of '
              '\u20B1${food.toStringAsFixed(2)} food price',
              style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
            ),
          ),
          Text('\u20B1${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Color(0xFF047857))),
        ],
      ),
    );
  }

  Widget _jobCard(DeliveryOrder o, {required bool isHistory}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHistory ? const Color(0xFFE5E7EB) : const Color(0xFFFFE0CC),
          width: isHistory ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(o.status.label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFFF6600))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.restaurantName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(o.deliveryAddress,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('\u20B1${o.total.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Color(0xFFFF6600), fontWeight: FontWeight.bold)),
          _earningRow(o),
          if (o.status.isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => RiderDeliveryScreen(orderId: o.id)),
                ),
                child: const Text('Start Delivery',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}