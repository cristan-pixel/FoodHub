// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:foodhub1/auth_service.dart';
import 'package:foodhub1/models/order_models.dart' as models;
import 'package:foodhub1/services/admin_auth_service.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/rider_earnings.dart';
import 'package:latlong2/latlong.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _orderFilters = ['All', 'Active', 'Delivered', 'Cancelled'];

  late final TabController _tabController;
  String _orderFilter = 'All';
  final TextEditingController _orderSearch = TextEditingController();
  final TextEditingController _customerSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderSearch.dispose();
    _customerSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D26),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Admin — FoodHub Ops',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await AdminAuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/role-select', (route) => false);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6600),
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFFF6600),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Orders'),
            Tab(text: 'Restaurants'),
            Tab(text: 'Riders'),
            Tab(text: 'Customers'),
            Tab(text: 'Live Map'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: AppData.instance,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _overviewTab(),
              _ordersTab(),
              _restaurantsTab(),
              _ridersTab(),
              _customersTab(),
              _liveMapTab(),
            ],
          );
        },
      ),
    );
  }

  // ── Shared bits ────────────────────────────────────────────────

  String _formattedDate(DateTime d) =>
      "${d.day}/${d.month}/${d.year} "
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  Future<bool> _confirm(String title, String message, String confirmLabel,
      {String dismissLabel = 'Go back'}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text(dismissLabel, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: const TextStyle(
                    color: Color(0xFFFF6600), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  InputDecoration _searchDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFFF6600)),
        ),
      );

  Widget _pill(String text, {required Color bg, required Color fg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
      );

  Widget _orderStatusChip(models.OrderStatus status) {
    final delivered = status == models.OrderStatus.delivered;
    final cancelled = status == models.OrderStatus.cancelled;
    return _pill(
      status.label,
      bg: delivered
          ? Colors.green.shade50
          : cancelled
              ? Colors.red.shade50
              : const Color(0xFFFFF3E0),
      fg: delivered
          ? Colors.green.shade700
          : cancelled
              ? Colors.red.shade700
              : const Color(0xFFFF6600),
    );
  }

  Expanded _statTile(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      );

  // ── Admin actions ──────────────────────────────────────────────

  Future<void> _cancelOrder(models.DeliveryOrder o) async {
    final ok = await _confirm(
      'Cancel order ${o.id}?',
      '${o.customerName} · ${o.restaurantName}. The order stops moving right away '
      'and everybody watching it is notified.',
      'Cancel order',
      dismissLabel: 'Keep order',
    );
    if (!mounted) return;
    if (ok) AppData.instance.adminCancelOrder(o.id);
  }

  Future<void> _deleteOrder(models.DeliveryOrder o) async {
    final ok = await _confirm(
      'Delete ${o.id} permanently?',
      'This permanently removes it for everyone — the customer, the restaurant '
      'and the rider will no longer see it. This cannot be undone.',
      'Delete forever',
      dismissLabel: 'Keep it',
    );
    if (!mounted) return;
    if (ok) AppData.instance.adminDeleteOrder(o.id);
  }

  Future<void> _toggleRestaurant(
      models.RestaurantAccount restaurant, bool accepting) async {
    final ok = await _confirm(
      accepting ? 'Resume ${restaurant.name}?' : 'Pause ${restaurant.name}?',
      accepting
          ? 'The restaurant starts receiving new orders again.'
          : 'The restaurant stops receiving new orders until you resume it.',
      accepting ? 'Resume' : 'Pause',
      dismissLabel: 'Go back',
    );
    if (!mounted) return;
    if (ok) {
      AppData.instance.adminSetRestaurantAccepting(restaurant.email, accepting);
    }
  }

  Future<void> _toggleRider(models.RiderAccount rider, bool online) async {
    final ok = await _confirm(
      online ? 'Bring ${rider.name} online?' : 'Take ${rider.name} offline?',
      online
          ? 'The rider becomes available for new deliveries again.'
          : 'The rider stops receiving new deliveries until you bring them back.',
      online ? 'Go online' : 'Go offline',
      dismissLabel: 'Go back',
    );
    if (!mounted) return;
    if (ok) AppData.instance.adminSetRiderOnline(rider.id, online);
  }

  // ── Overview ───────────────────────────────────────────────────

  Widget _overviewTab() {
    final data = AppData.instance;
    final now = DateTime.now();
    final cancelledToday = data.orders
        .where((o) =>
            o.status == models.OrderStatus.cancelled &&
            o.placedAt.year == now.year &&
            o.placedAt.month == now.month &&
            o.placedAt.day == now.day)
        .length;
    final onlineRiders = data.riders.where((r) => r.online).length;
    final stats = [
      ('Active Orders', data.activeOrderCount.toString(), Icons.local_shipping_outlined),
      ('Delivered Today', data.deliveredTodayCount.toString(), Icons.check_circle_outline),
      ('Cancelled Today', cancelledToday.toString(), Icons.cancel_outlined),
      ('Online Riders', onlineRiders.toString(), Icons.delivery_dining_outlined),
      ('Restaurants', data.restaurants.length.toString(), Icons.storefront_outlined),
      ('Riders', data.riders.length.toString(), Icons.two_wheeler),
      ('Total Revenue', '\u20B1${data.totalRevenue.toStringAsFixed(2)}', Icons.payments_outlined),
    ];
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: stats
          .map((s) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s.$3, color: const Color(0xFFFF6600)),
                    const Spacer(),
                    Text(s.$2,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(s.$1,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Orders ─────────────────────────────────────────────────────

  bool _matchesOrderFilter(models.OrderStatus status) {
    switch (_orderFilter) {
      case 'Active':
        return status.isActive;
      case 'Delivered':
        return status == models.OrderStatus.delivered;
      case 'Cancelled':
        return status == models.OrderStatus.cancelled;
      default:
        return true;
    }
  }

  Widget _ordersTab() {
    final query = _orderSearch.text.trim().toLowerCase();
    final orders = AppData.instance.orders.where((o) {
      if (!_matchesOrderFilter(o.status)) return false;
      if (query.isEmpty) return true;
      return o.id.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query) ||
          o.restaurantName.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _orderSearch,
            onChanged: (_) => setState(() {}),
            decoration:
                _searchDecoration('Search order id, customer or restaurant'),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            children: _orderFilters
                .map((f) {
                  final selected = _orderFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : Colors.grey[700])),
                      selected: selected,
                      onSelected: (_) => setState(() => _orderFilter = f),
                      selectedColor: const Color(0xFFFF6600),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                    ),
                  );
                })
                .toList(),
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(
                  child: Text('No orders match this view.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _orderRow(orders[i]),
                ),
        ),
      ],
    );
  }

  Widget _orderRow(models.DeliveryOrder o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${o.id} · ${o.customerName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(o.restaurantName,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(o.orderSummary,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Text(_formattedDate(o.placedAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                Text(
                    o.assignedRiderName != null
                        ? 'Rider: ${o.assignedRiderName}'
                        : 'Rider: unassigned',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\u20B1${o.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _orderStatusChip(o.status),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                tooltip: 'Order actions',
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'cancel') {
                    _cancelOrder(o);
                  } else if (value == 'delete') {
                    _deleteOrder(o);
                  }
                },
                itemBuilder: (_) => [
                  if (o.status.isActive)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel order',
                          style: TextStyle(color: Color(0xFFFF6600))),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete order',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Restaurants ────────────────────────────────────────────────

  Widget _restaurantsTab() {
    final restaurants = AppData.instance.restaurants;
    if (restaurants.isEmpty) {
      return const Center(
          child: Text('No partner restaurants yet.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: restaurants.length,
      itemBuilder: (_, i) => _restaurantCard(restaurants[i]),
    );
  }

  Widget _restaurantCard(models.RestaurantAccount restaurant) {
    final data = AppData.instance;
    final sold = data.restaurantSoldItems(restaurant.name).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sold.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.storefront, color: Color(0xFFFF6600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${restaurant.cuisine} · ${restaurant.address}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              restaurant.acceptingOrders
                  ? _pill('Accepting orders',
                      bg: Colors.green.shade50, fg: Colors.green.shade700)
                  : _pill('Paused',
                      bg: Colors.red.shade50, fg: Colors.red.shade700),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTile('Orders',
                  data.restaurantOrderCount(restaurant.name).toString()),
              _statTile('Revenue',
                  '\u20B1${data.restaurantRevenue(restaurant.name).toStringAsFixed(2)}'),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Top sold',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: top
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${e.key} ×${e.value}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFFF6600))),
                      ))
                  .toList(),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurant.acceptingOrders
                      ? 'Accepting orders'
                      : 'Paused — not taking new orders',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: restaurant.acceptingOrders,
                activeColor: const Color(0xFFFF6600),
                onChanged: (v) => _toggleRestaurant(restaurant, v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Riders ─────────────────────────────────────────────────────

  Widget _ridersTab() {
    final riders = AppData.instance.riders;
    if (riders.isEmpty) {
      return const Center(
          child: Text('No riders registered yet.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: riders.length,
      itemBuilder: (_, i) => _riderCard(riders[i]),
    );
  }

  Widget _riderCard(models.RiderAccount rider) {
    final data = AppData.instance;
    final assigned = data.ordersForRider(rider.id);
    final active = assigned.where((o) => o.status.isActive).length;
    final now = DateTime.now();
    final delivered =
        assigned.where((o) => o.status == models.OrderStatus.delivered);
    final todayEarnings = delivered
        .where((o) => RiderEarnings.isSameDay(
            RiderEarnings.deliveredAt(o), now))
        .fold<double>(0, (sum, o) => sum + RiderEarnings.amountFor(o));
    final totalEarnings = delivered.fold<double>(
        0, (sum, o) => sum + RiderEarnings.amountFor(o));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.two_wheeler, color: Color(0xFFFF6600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rider.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${rider.email} · ${rider.vehicle}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              rider.online
                  ? _pill('Online',
                      bg: Colors.green.shade50, fg: Colors.green.shade700)
                  : _pill('Offline',
                      bg: Colors.grey.shade100, fg: Colors.grey.shade700),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTile('Active deliveries', active.toString()),
              _statTile('Total deliveries', assigned.length.toString()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statTile(
                'Earned today',
                '\u20B1${todayEarnings.toStringAsFixed(2)}',
              ),
              _statTile(
                'Total earned',
                '\u20B1${totalEarnings.toStringAsFixed(2)}',
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  rider.online
                      ? 'Available for new deliveries'
                      : 'Deactivated — no new deliveries',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showRiderEarnings(rider),
                icon: const Icon(Icons.bar_chart_outlined, size: 18),
                label: const Text('Daily earnings',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6600),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Switch(
                value: rider.online,
                activeColor: const Color(0xFFFF6600),
                onChanged: (v) => _toggleRider(rider, v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<models.DeliveryOrder>> _deliveredByDay(
      List<models.DeliveryOrder> orders) {
    final map = <DateTime, List<models.DeliveryOrder>>{};
    for (final o in orders) {
      if (o.status != models.OrderStatus.delivered) continue;
      final at = RiderEarnings.deliveredAt(o);
      final key = DateTime(at.year, at.month, at.day);
      map.putIfAbsent(key, () => []).add(o);
    }
    return map;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  Widget _sheetStat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      );

  Future<void> _showRiderEarnings(models.RiderAccount rider) {
    final byDay = _deliveredByDay(AppData.instance.ordersForRider(rider.id));
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final deliveries =
        days.fold<int>(0, (sum, d) => sum + byDay[d]!.length);
    final total = days.fold<double>(
        0,
        (sum, d) =>
            sum +
            byDay[d]!.fold<double>(
                0, (s, o) => s + RiderEarnings.amountFor(o)));

    String money(double v) => '\u20B1${v.toStringAsFixed(2)}';

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily earnings',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(rider.name,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _sheetStat('All-time', money(total)),
                  _sheetStat('Deliveries', deliveries.toString()),
                  _sheetStat('Rate', RiderEarnings.percentLabel),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: days.isEmpty
                  ? const Center(
                      child: Text('No completed deliveries yet.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: days.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (_, i) {
                        final day = days[i];
                        final orders = byDay[day]!;
                        final earned = orders.fold<double>(0,
                            (s, o) => s + RiderEarnings.amountFor(o));
                        final food = orders.fold<double>(0,
                            (s, o) => s + RiderEarnings.foodSubtotal(o));
                        return Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text('${day.day}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF6600))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_dayLabel(day),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                    '${orders.length} deliveries \u00B7 '
                                    'food ${money(food)}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(money(earned),
                                style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Customers ──────────────────────────────────────────────────

  Widget _customersTab() {
    final query = _customerSearch.text.trim().toLowerCase();
    final users = AuthService.instance.users.where((u) {
      if (query.isEmpty) return true;
      return (u['name'] ?? '').toLowerCase().contains(query) ||
          (u['email'] ?? '').toLowerCase().contains(query);
    }).toList();

    if (users.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty
              ? 'No registered customers yet.'
              : 'No customers match your search.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _customerSearch,
            onChanged: (_) => setState(() {}),
            decoration: _searchDecoration('Search customer name or email'),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: users.length,
            itemBuilder: (_, i) => _customerCard(users[i]),
          ),
        ),
      ],
    );
  }

  Widget _customerCard(Map<String, String> user) {
    final email = user['email'] ?? '';
    final myOrders = AppData.instance.ordersForCustomer(email);
    final spend = myOrders.fold<double>(
        0.0,
        (sum, o) =>
            sum + (o.status == models.OrderStatus.cancelled ? 0 : o.total));

    return GestureDetector(
      onTap: () => _showCustomerOrders(user['name'] ?? '', email),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFFF3E0),
              child: Icon(Icons.person_outline, color: Color(0xFFFF6600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(email,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${myOrders.length} order(s)',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\u20B1${spend.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFFF6600),
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerOrders(String name, String email) {
    final orders = AppData.instance.ordersForCustomer(email);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: orders.isEmpty
              ? const Text('No orders yet.', style: TextStyle(color: Colors.grey))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${o.id} · ${o.restaurantName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(
                          '${_formattedDate(o.placedAt)} · '
                          '\u20B1${o.total.toStringAsFixed(2)}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: _orderStatusChip(o.status),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFFFF6600))),
          ),
        ],
      ),
    );
  }

  // ── Live map ───────────────────────────────────────────────────

  Widget _liveMapTab() {
    final active = AppData.instance.orders.where((o) => o.status.isActive).toList();

    final markers = <Marker>[];
    for (final r in AppData.instance.restaurants) {
      markers.add(Marker(
        point: LatLng(r.location.lat, r.location.lng),
        child: _mapPin(const Color(0xFFFF6600), Icons.storefront_outlined),
      ));
    }
    for (final o in active) {
      markers.add(Marker(
        point: LatLng(o.customerLocation.lat, o.customerLocation.lng),
        child: _mapPin(const Color(0xFF1E88E5), Icons.home_outlined),
      ));
      if (o.riderLocation != null) {
        markers.add(Marker(
          point: LatLng(o.riderLocation!.lat, o.riderLocation!.lng),
          width: 38,
          height: 38,
          child: _mapPin(const Color(0xFF00C566), Icons.bolt, isLive: true),
        ));
      }
    }

    final center = markers.isNotEmpty
        ? markers.first.point
        : const LatLng(8.0659, 123.7477); // Tangub City center

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFFFF3E0),
          child: Text(
            '${active.length} active order(s) · orange = restaurant, green = rider (live GPS), blue = delivery address',
            style: const TextStyle(fontSize: 12, color: Colors.brown),
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              backgroundColor: const Color(0xFFE8EAED),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.foodhub.app',
              ),
              MarkerLayer(markers: markers),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapPin(Color color, IconData icon, {bool isLive = false}) {
    return Container(
      width: 30,
      height: 30,
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
          Icon(icon, color: Colors.white, size: 17),
          if (isLive)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 10,
                height: 10,
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
