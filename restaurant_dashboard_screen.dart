// lib/screens/restaurant/restaurant_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/menu_items.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/restaurant_auth_service.dart';
import 'package:foodhub1/widgets/live_order_map.dart';

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = RestaurantAuthService.instance.currentRestaurant;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Expanded(
              child: Text(restaurant?.name ?? 'Restaurant',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            // Pause/resume switch: when off, customers see this partner
            // as not accepting orders (persisted to the cloud).
            _acceptingSwitch(restaurant?.acceptingOrders ?? true),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await RestaurantAuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/restaurant/login', (route) => false);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6600),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6600),
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'In Progress'),
            Tab(text: 'Menu'),
            Tab(text: 'Earnings'),
          ],
        ),
      ),
      body: restaurant == null
          ? const Center(child: Text('Not signed in'))
          : Column(
              children: [
                if (!restaurant.acceptingOrders) _pausedBanner(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: AppData.instance,
                    builder: (context, _) {
                      final all = AppData.instance
                          .ordersForRestaurant(restaurant.name);
                      final incoming = all
                          .where((o) => o.status == OrderStatus.placed)
                          .toList();
                      final inProgress = all
                          .where((o) => [
                                OrderStatus.restaurantAccepted,
                                OrderStatus.preparing,
                                OrderStatus.readyForPickup,
                                OrderStatus.riderAssigned,
                                OrderStatus.pickedUp,
                                OrderStatus.onTheWay,
                              ].contains(o.status))
                          .toList();

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _list(incoming, 'No new orders yet.', _incomingCard),
                          _list(inProgress, 'Nothing in progress.', _progressCard),
                          _menuTab(restaurant.name),
                          _earningsTab(restaurant.name),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _acceptingSwitch(bool accepting) {
    return Tooltip(
      message: accepting
          ? 'Accepting orders — customers can order from you'
          : 'Paused — customers cannot place new orders',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle,
              size: 9, color: accepting ? Colors.green : Colors.orange),
          const SizedBox(width: 4),
          Switch(
            value: accepting,
            activeTrackColor: Colors.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: RestaurantAuthService.instance.setAcceptingOrders,
          ),
        ],
      ),
    );
  }

  Widget _pausedBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 16, color: Color(0xFFFF6600)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are paused — customers cannot place new orders right now.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A4B00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<DeliveryOrder> orders, String emptyText,
      Widget Function(DeliveryOrder) builder) {
    if (orders.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => builder(orders[i]),
    );
  }

  Widget _cardShell({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: child,
      );

  Widget _incomingCard(DeliveryOrder o) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('\u20B1${o.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFFFF6600), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.orderSummary),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => AppData.instance.restaurantReject(o.id),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6600),
                  ),
                  onPressed: () => AppData.instance.restaurantAccept(o.id),
                  child: const Text('Accept',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressCard(DeliveryOrder o) {
    Widget? actionButton;
    switch (o.status) {
      case OrderStatus.restaurantAccepted:
        actionButton = _actionBtn('Start Preparing',
            () => AppData.instance.restaurantStartPreparing(o.id));
        break;
      case OrderStatus.preparing:
        actionButton = _actionBtn(
            'Mark Ready for Pickup', () => AppData.instance.restaurantMarkReady(o.id));
        break;
      case OrderStatus.readyForPickup:
        actionButton = _actionBtn('Choose a Rider', () => _chooseRider(o));
        break;
      default:
        actionButton = null;
    }

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(o.status.label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFF6600))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.orderSummary),
          if (o.assignedRiderName != null) ...[
            const SizedBox(height: 4),
            Text('Rider: ${o.assignedRiderName}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
          if (o.status == OrderStatus.riderAssigned ||
              o.status == OrderStatus.pickedUp ||
              o.status == OrderStatus.onTheWay) ...[
            const SizedBox(height: 12),
            LiveOrderMap(orderId: o.id, height: 180),
          ],
          if (actionButton != null) ...[
            const SizedBox(height: 12),
            actionButton,
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
      );

  /// Lets the restaurant hand an order to one of the available riders.
  void _chooseRider(DeliveryOrder o) {
    final riders = AppData.instance.availableRiders();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose a rider',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Available riders for ${o.id}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (riders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No available riders right now.\n'
                  'Riders are shown when they are online and not on a delivery.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: riders.length,
                  itemBuilder: (_, i) {
                    final r = riders[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFF3E0),
                        child: const Icon(Icons.delivery_dining_outlined,
                            color: Color(0xFFFF6600)),
                      ),
                      title: Text(r.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(r.vehicle),
                      trailing: const Icon(Icons.add_circle,
                          color: Color(0xFFFF6600)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        AppData.instance.restaurantAssignRider(o.id, r.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${r.name} is now delivering ${o.id}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuTab(String restaurantName) {
    final items = restaurantMenus[restaurantName] ?? [];
    if (items.isEmpty) {
      return const Center(
          child: Text('No menu items yet.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return _cardShell(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(item['desc'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text('\u20B1${item['price']}',
                  style: const TextStyle(
                      color: Color(0xFFFF6600), fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _earningsTab(String restaurantName) {
    final revenue = AppData.instance.restaurantRevenue(restaurantName);
    final orderCount = AppData.instance.restaurantOrderCount(restaurantName);
    final soldItems = AppData.instance.restaurantSoldItems(restaurantName);

    final sorted = soldItems.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D26),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL EARNINGS',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Text('\u20B1${revenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStat(orderCount, 'Orders'),
                  const SizedBox(width: 16),
                  _miniStat(sorted.fold(0, (s, e) => s + e.value), 'Items sold'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Sold Menu Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No items sold yet.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ...sorted.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('${e.value} sold',
                        style: const TextStyle(
                            color: Color(0xFFFF6600),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _miniStat(int value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
}
