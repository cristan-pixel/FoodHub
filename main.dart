// lib/main.dart  (updated — replaces your existing main.dart)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:foodhub1/catergory_section.dart';
import 'package:foodhub1/checkout_dialog.dart';
import 'package:foodhub1/dish_grid.dart';
import 'package:foodhub1/hero_section.dart';
import 'package:foodhub1/login_screen.dart';
import 'package:foodhub1/menu_items.dart';
import 'package:foodhub1/order_tracking_screen.dart';
import 'package:foodhub1/profile_sheet.dart';
import 'package:foodhub1/restaurant_grid.dart';
import 'package:foodhub1/signup_screen.dart';
import 'package:foodhub1/screens/role_select_screen.dart';
import 'package:foodhub1/screens/rider/rider_login_screen.dart';
import 'package:foodhub1/screens/rider/rider_dashboard_screen.dart';
import 'package:foodhub1/screens/restaurant/restaurant_login_screen.dart';
import 'package:foodhub1/screens/restaurant/restaurant_dashboard_screen.dart';
import 'package:foodhub1/screens/admin/admin_login_screen.dart';
import 'package:foodhub1/screens/admin/admin_dashboard_screen.dart';
import 'package:foodhub1/auth_service.dart';
import 'package:foodhub1/services/admin_auth_service.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/services/firebase_auth_adapter.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/notification_service.dart';
import 'package:foodhub1/services/restaurant_auth_service.dart';
import 'package:foodhub1/services/rider_auth_service.dart';
import 'package:foodhub1/services/session_context.dart';
import 'package:foodhub1/services/session_manager.dart';
import 'package:foodhub1/widgets/app_logo.dart';

/// Lets notification taps navigate even when the app was cold-started
/// from the background by a push.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Starts Firebase if it's configured on this device (never throws;
  // falls back to in-memory demo data when no backend is present).
  final firebase = FirebaseSyncService.instance;
  await firebase.ensureInitialized();
  if (firebase.isEnabled) {
    // Online mode: push the bundled catalog once, then hydrate the local
    // store from Firestore and start listening for live changes.
    await firebase.seedCatalog();
    unawaited(AppData.instance.attachFirestoreStreams());
    unawaited(AuthService.instance.hydrateFromFirestore());
    AuthService.instance.attachUsersStream();
    unawaited(RiderAuthService.instance.hydrateFromFirestore());
    unawaited(RestaurantAuthService.instance.hydrateFromFirestore());

    // If a session is still alive from the previous launch, finish
    // hydrating first so the restored dashboard has its data, then
    // resume straight into the right screen.
    await SessionManager.loadPersistedSession();
    if (SessionManager.restoredRole != null) {
      await AppData.instance
          .attachFirestoreStreams()
          .timeout(const Duration(seconds: 8), onTimeout: () {});
      await AuthService.instance
          .hydrateFromFirestore()
          .timeout(const Duration(seconds: 8), onTimeout: () {});
      await RiderAuthService.instance
          .hydrateFromFirestore()
          .timeout(const Duration(seconds: 8), onTimeout: () {});
      await RestaurantAuthService.instance
          .hydrateFromFirestore()
          .timeout(const Duration(seconds: 8), onTimeout: () {});
    }
  }

  await NotificationService.instance.initialize();
  final initialRoute = await _restoreSession();

  // Tapping a push opens the signed-in role's main screen.
  NotificationService.instance.onNotificationTap.listen((_) {
    final route = _homeRouteForCurrentSession();
    if (route == null) return;
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(route, (r) => false);
  });

  runApp(FoodHubApp(initialRoute: initialRoute));
}

/// Resumes the role session Firebase Auth still holds (if any).
Future<String?> _restoreSession() async {
  try {
    if (!FirebaseAuthAdapter.enabled) return null;
    final role = SessionManager.restoredRole;
    if (role == null) return null;
    switch (role) {
      case SessionRole.customer:
        final email = await AuthService.instance.restoreSession();
        return email == null ? null : '/home';
      case SessionRole.rider:
        return await RiderAuthService.instance.restoreSession()
            ? '/rider/dashboard'
            : null;
      case SessionRole.restaurant:
        return await RestaurantAuthService.instance.restoreSession()
            ? '/restaurant/dashboard'
            : null;
      case SessionRole.admin:
        return await AdminAuthService.instance.restoreSession()
            ? '/admin/dashboard'
            : null;
    }
  } catch (_) {
    return null; // Any hiccup → show the role picker, like a fresh launch.
  }
}

String? _homeRouteForCurrentSession() {
  switch (SessionContext.role) {
    case SessionRole.customer:
      return '/home';
    case SessionRole.rider:
      return '/rider/dashboard';
    case SessionRole.restaurant:
      return '/restaurant/dashboard';
    case SessionRole.admin:
      return '/admin/dashboard';
    case null:
      return null;
  }
}

class FoodHubApp extends StatelessWidget {
  const FoodHubApp({super.key, this.initialRoute});

  final String? initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6600)),
        useMaterial3: false,
      ),
      // ── Entry point: resume the live session when there is one,
      // otherwise pick a role, then each role has its own login flow. ──
      initialRoute: initialRoute ?? '/role-select',
      routes: {
        '/role-select': (_) => const RoleSelectScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/home': (_) => const HomePage(),
        '/rider/login': (_) => const RiderLoginScreen(),
        '/rider/dashboard': (_) => const RiderDashboardScreen(),
        '/restaurant/login': (_) => const RestaurantLoginScreen(),
        '/restaurant/dashboard': (_) => const RestaurantDashboardScreen(),
        '/admin/login': (_) => const AdminLoginScreen(),
        '/admin/dashboard': (_) => const AdminDashboardScreen(),
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The rest of this file is your existing HomePage — unchanged.
// ════════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _selectedCategory = "All";
  String _searchQuery = "";

  final List<Map<String, dynamic>> _cartItems = [];
  final List<Map<String, dynamic>> _orderHistory = [];

  final Set<String> _favoriteNames = {};

  void _toggleFavorite(String name) {
    setState(() {
      if (_favoriteNames.contains(name)) {
        _favoriteNames.remove(name);
      } else {
        _favoriteNames.add(name);
      }
    });
  }

  String _address = "123 Main St, Apt 4B";
  String _paymentMethod = "GCash";

  @override
  void initState() {
    super.initState();
    // Start from the customer's saved profile (falls back to the demo
    // address until one is added in the profile sheet).
    final saved = AuthService.instance.defaultAddress;
    if (saved.isNotEmpty) _address = saved;
    // Live partner/order changes (a restaurant pausing, a new order
    // landing in history) should redraw the home feed.
    AppData.instance.addListener(_onAppDataChanged);
  }

  void _onAppDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    super.dispose();
  }

  /// Partners that are currently not accepting orders — their cards get
  /// a paused badge and checkout refuses their items.
  Set<String> get _pausedRestaurants => AppData.instance.restaurants
      .where((r) => !r.acceptingOrders)
      .map((r) => r.name)
      .toSet();

  final List<Map<String, String>> _allRestaurants = allRestaurants;

  List<Map<String, String>> get _filteredRestaurants {
    // Show both restaurants; search filters by name/tags/dishes.
    List<Map<String, String>> result = _allRestaurants;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((r) =>
              (r['name']!).toLowerCase().contains(q) ||
              (r['tags']!).toLowerCase().contains(q) ||
              (r['category']!).toLowerCase().contains(q) ||
              (restaurantMenus[r['name']] ?? []).any(
                  (item) => (item['name'] ?? '').toLowerCase().contains(q)))
          .toList();
    }
    return result;
  }

  /// Returns all dishes from every restaurant that match the selected
  /// category, with each dish carrying its `restaurant_name`.
  List<Map<String, dynamic>> get _filteredDishes {
    if (_selectedCategory == 'All') return [];
    final dishes = <Map<String, dynamic>>[];
    for (final entry in restaurantMenus.entries) {
      final rName = entry.key;
      for (final item in entry.value) {
        if (item['category'] == _selectedCategory) {
          dishes.add({...item, 'restaurant_name': rName});
        }
      }
    }
    return dishes;
  }

  void _handleOrderNow(Map<String, String> restaurant) {
    setState(() {
      // The "restaurant" this item belongs to. For dish-level items the
      // menu passes `restaurant_name`; for the whole-restaurant Order
      // button it's the restaurant itself.
      final rName = restaurant['restaurant_name'] ?? restaurant['name']!;

      final idx =
          _cartItems.indexWhere((item) => item['name'] == restaurant['name']);
      if (idx != -1) {
        _cartItems[idx]['qty'] = (_cartItems[idx]['qty'] as int) + 1;
      } else {
        String image = restaurant['image'] ?? '';
        if (image.isEmpty) {
          final List items = restaurantMenus[rName] ?? [];
          if (items.isNotEmpty) {
            image = items.first['image'] ?? '';
          }
        }

        // Dishes carry no per-item prep time — fall back to their
        // restaurant's published prep time so the ETA is never "0 mins".
        String prep = restaurant['prep'] ?? '';
        if (prep.isEmpty || prep == '0') {
          prep = _prepTimeFor(rName);
        }

        _cartItems.add({
          "name": restaurant['name'] ?? 'Unknown Item',
          "restaurant_name": rName,
          "price": restaurant['price'] ?? '0.00',
          "qty": 1,
          "prep": prep,
          "image": image,
        });
      }
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  String _prepTimeFor(String restaurantName) {
    for (final r in _allRestaurants) {
      if (r['name'] == restaurantName) {
        final prep = r['prep'];
        if (prep != null && prep.isNotEmpty && prep != '0') return prep;
      }
    }
    return '20';
  }

  String _calculateTimeline() {
    if (_cartItems.isEmpty) return "0 mins";
    final maxPrep = _cartItems
        .map((item) => int.tryParse(item['prep'].toString()) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return "$maxPrep mins (Shop Prep Time)";
  }

  double _calculateSubtotal() {
    double total = 0;
    for (final item in _cartItems) {
      total += double.parse(item['price'].toString()) * (item['qty'] as int);
    }
    return total;
  }

  int get _cartCount =>
      _cartItems.fold(0, (sum, item) => sum + (item['qty'] as int));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            AppLogo(size: 30),
            SizedBox(width: 8),
            Text(
              "FoodHub",
              style: TextStyle(
                color: Color(0xFFFF6600),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black),
            tooltip: "Order History",
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            tooltip: "Profile",
            onPressed: () => _showProfileSheet(),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined,
                    color: Colors.black),
                tooltip: "Cart",
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6600),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "$_cartCount",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: _buildHistoryDrawer(),
      endDrawer: _buildCartDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            HeroSection(
              onSearch: (query) => setState(() => _searchQuery = query),
            ),
            CategorySection(
              selectedCategory: _selectedCategory,
              onCategorySelected: (cat) =>
                  setState(() => _selectedCategory = cat),
            ),
            if (_selectedCategory == 'All')
              RestaurantGrid(
                restaurants: _filteredRestaurants,
                onOrderPressed: _handleOrderNow,
                favoriteNames: _favoriteNames,
                onToggleFavorite: _toggleFavorite,
                pausedNames: _pausedRestaurants,
              )
            else
              DishGrid(
                dishes: _filteredDishes,
                onAddToCart: (dish) =>
                    _handleOrderNow(Map<String, String>.from(dish)),
              ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) => ProfileSheet(
            address: _address,
            allRestaurants: _allRestaurants,
            favoriteNames: _favoriteNames,
            orderHistory: List<Map<String, dynamic>>.from(_orderHistory),
            onToggleFavorite: (name) {
              _toggleFavorite(name);
              setModalState(() {});
            },
            onOrderFromFavorites: (restaurant) {
              Navigator.pop(context);
              _handleOrderNow(restaurant);
            },
            onUpdateAddress: (v) => setState(() => _address = v),
            onUpdatePayment: (v) => setState(() => _paymentMethod = v),
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Order History",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(builder: (context) {
                // Live customer orders straight from the shared store
                // (synced with Firestore) so history and progress survive
                // a logout/login or app restart.
                final email = AuthService.instance.currentEmail;
                final liveOrders = email != null
                    ? AppData.instance.ordersForCustomer(email)
                    : const [];
                if (liveOrders.isNotEmpty) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: liveOrders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final order = liveOrders[i];
                      final items = order.items;
                      final String img = items.isNotEmpty
                          ? items.first['image'] as String? ?? ''
                          : '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: img.isNotEmpty
                              ? Image.asset(
                                  img,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _orderIcon(),
                                )
                              : _orderIcon(),
                        ),
                        title: Text(
                          order.orderSummary,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${order.status.label} · ${_formattedDate(order.placedAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderTrackingScreen(
                              totalAmount: order.total,
                              deliveryTime: _estimatePrep(order.items),
                              orderSummary: order.orderSummary,
                              orderNumber: order.id,
                              deliveryAddress: order.deliveryAddress,
                              paymentMethod: order.paymentMethod,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "\u20B1${order.total.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: Color(0xFFFF6600),
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right,
                                size: 20, color: Colors.black26),
                          ],
                        ),
                      );
                    },
                  );
                }
                if (_orderHistory.isNotEmpty) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _orderHistory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final order = _orderHistory[i];
                      final String img = order['image'] as String? ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: img.isNotEmpty
                              ? Image.asset(
                                  img,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _orderIcon(),
                                )
                              : _orderIcon(),
                        ),
                        title: Text(
                          order['summary'] as String? ?? "Order",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          order['date'] as String? ?? "",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: Text(
                          "\u20B1${(order['total'] as double).toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Color(0xFFFF6600),
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  );
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text("No orders yet",
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text("Your completed orders will appear here",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartDrawer() {
    final subtotal = _calculateSubtotal();
    const deliveryFee = 3.99;
    final tax = subtotal * 0.08;
    final total = subtotal + deliveryFee + tax;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.92,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Your Cart ($_cartCount)",
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_cartItems.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text("Your cart is empty",
                          style: TextStyle(color: Colors.grey, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text("Add items from restaurants to get started",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else ...[
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _cartItems.length,
                  itemBuilder: (context, i) {
                    final item = _cartItems[i];
                    final String itemImg = item['image'] as String? ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: itemImg.isNotEmpty
                                ? Image.asset(
                                    itemImg,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFFFE0CC),
                                      child: const Icon(Icons.restaurant,
                                          color: Color(0xFFFF6600), size: 28),
                                    ),
                                  )
                                : Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE0CC),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.restaurant,
                                        color: Color(0xFFFF6600), size: 28),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "\u20B1${item['price']}",
                                  style: const TextStyle(
                                      color: Color(0xFFFF6600),
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _qtyButton(
                                      icon: Icons.remove,
                                      onTap: () => setState(() {
                                        final qty = item['qty'] as int;
                                        if (qty > 1) {
                                          item['qty'] = qty - 1;
                                        } else {
                                          _cartItems.removeAt(i);
                                        }
                                      }),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        "${item['qty']}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                    _qtyButton(
                                      icon: Icons.add,
                                      onTap: () => setState(() {
                                        item['qty'] = (item['qty'] as int) + 1;
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "\u20B1${(double.parse(item['price'].toString()) * (item['qty'] as int)).toStringAsFixed(2)}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _buildCartFooter(subtotal, deliveryFee, tax, total),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildCartFooter(double sub, double fee, double tax, double tot) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F2F4))),
      ),
      child: Column(
        children: [
          _row("Subtotal", "\u20B1${sub.toStringAsFixed(2)}"),
          _row("Delivery Fee", "\u20B1${fee.toStringAsFixed(2)}"),
          _row("Tax (8%)", "\u20B1${tax.toStringAsFixed(2)}"),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text("\u20B1${tot.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => CheckoutDialog(
                    cartItems: List<Map<String, dynamic>>.from(_cartItems),
                    totalAmount: tot,
                    currentAddress: _address,
                    deliveryTime: _calculateTimeline(),
                    currentPayment: _paymentMethod,
                    onUpdateAddress: (v) => setState(() => _address = v),
                    onUpdatePayment: (v) => setState(() => _paymentMethod = v),
                    onOrderPlaced: () {
                      // Safety: the cart may already be cleared if the
                      // Place Order button was tapped twice — guard so
                      // '.first' never throws "Bad state: No element".
                      if (_cartItems.isEmpty) return;
                      final first = _cartItems.first;
                      final summary = _cartItems.length == 1
                          ? (first['name'] as String? ?? 'Order')
                          : "${first['name']} +${_cartItems.length - 1} more";
                      setState(() {
                        _orderHistory.insert(0, {
                          "summary": summary,
                          "total": tot,
                          "date": _formattedNow(),
                          "image": (first['image'] as String?) ?? '',
                        });
                        _cartItems.clear();
                      });
                    },
                  ),
                );
              },
              child: const Text(
                "Proceed to Checkout",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(color: Colors.grey)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );

  String _formattedNow() {
    final now = DateTime.now();
    return "${now.day}/${now.month}/${now.year} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  Widget _orderIcon() => Container(
        width: 48,
        height: 48,
        color: const Color(0xFFFFF3E0),
        child: const Icon(Icons.receipt_outlined, color: Color(0xFFFF6600)),
      );

  String _estimatePrep(List<Map<String, dynamic>> items) {
    var max = 0;
    for (final i in items) {
      final p = int.tryParse('${i['prep']}') ?? 0;
      if (p > max) max = p;
    }
    return max == 0 ? '30 mins' : '$max mins (Shop Prep Time)';
  }

  String _formattedDate(DateTime d) => "${d.day}/${d.month}/${d.year} "
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
}
