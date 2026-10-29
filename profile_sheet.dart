// lib/widgets/profile_sheet.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foodhub1/auth_service.dart';
import 'package:foodhub1/menu_items.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:foodhub1/services/app_data.dart';
import 'package:foodhub1/widgets/restaurant_menu_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSheet extends StatefulWidget {
  final String address;
  final String paymentMethod;
  final List<Map<String, String>> allRestaurants;
  // FIX: orderHistory is now properly passed from HomePage
  final List<Map<String, dynamic>> orderHistory;
  final Function(String) onUpdateAddress;
  final Function(String) onUpdatePayment;
  final ScrollController scrollController;

  // ── Favorites wired from HomePage ──────────────────────────
  final Set<String> favoriteNames;
  final Function(String) onToggleFavorite;

  // FIX: "Order Now" in Favorites tab triggers cart logic in HomePage
  final Function(Map<String, String>) onOrderFromFavorites;

  const ProfileSheet({
    super.key,
    required this.address,
    required this.allRestaurants,
    required this.onUpdateAddress,
    required this.onUpdatePayment,
    required this.scrollController,
    required this.favoriteNames,
    required this.onToggleFavorite,
    required this.onOrderFromFavorites,
    this.paymentMethod = 'GCash',
    this.orderHistory = const [],
  });

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Profile ────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  // ── Loyalty ────────────────────────────────────────────────
  int get _loyaltyPoints => AuthService.instance.loyaltyPoints;

  // ── Notifications ──────────────────────────────────────────
  bool _notifOrders    = true;
  bool _notifPromos    = true;
  bool _notifDelivery  = true;
  bool _notifEmail     = false;

  // ── Addresses ──────────────────────────────────────────────
  late List<Map<String, String>> _addresses;

  // ── Payment Methods ────────────────────────────────────────
  late List<Map<String, String>> _payments;

  // ── Referral ───────────────────────────────────────────────
  String get _referralCode => AuthService.instance.referralCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() => setState(() {}));

    final auth = AuthService.instance;
    _nameCtrl  = TextEditingController(text: auth.currentName ?? 'Guest');
    _emailCtrl = TextEditingController(text: auth.currentEmail ?? '');
    _phoneCtrl = TextEditingController(text: auth.phone);

    final savedAddresses = auth.addresses;
    if (savedAddresses.isNotEmpty) {
      _addresses = [
        for (var i = 0; i < savedAddresses.length; i++)
          {
            'label': i == savedAddresses.length - 1 ? 'Home' : 'Address ${i + 1}',
            'address': savedAddresses[i],
            'isDefault': i == savedAddresses.length - 1 ? 'true' : 'false',
            'saved': 'true',
          },
      ];
    } else {
      _addresses = [
        {
          'label': 'Home',
          'address': widget.address,
          'isDefault': 'true',
          'saved': 'false',
        },
      ];
    }

    final savedPayments = auth.paymentMethods;
    if (savedPayments.isNotEmpty) {
      _payments = [
        for (var i = 0; i < savedPayments.length; i++)
          {
            'type': savedPayments[i]['label'] ?? 'Payment',
            'detail': savedPayments[i]['details'] ?? '',
            'isDefault': i == 0 ? 'true' : 'false',
            'saved': 'true',
          },
      ];
    } else {
      _payments = [
        {
          'type': 'GCash',
          'detail': 'linked',
          'isDefault': 'true',
          'saved': 'false',
        },
        {
          'type': 'Cash on Delivery',
          'detail': 'always available',
          'isDefault': 'false',
          'saved': 'false',
        },
      ];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _favorites => widget.allRestaurants
      .where((r) => widget.favoriteNames.contains(r['name']))
      .toList();

  void _snack(String msg, {Color bg = const Color(0xFFFF6600)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFFF6600),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6600),
          indicatorWeight: 2.5,
          tabAlignment: TabAlignment.start,
          tabs: [
            _tab(Icons.person_outline, 'Profile'),
            _tab(Icons.star_border_rounded, 'Loyalty'),
            _tab(Icons.favorite_border, 'Favorites'),
            _tab(Icons.location_on_outlined, 'Addresses'),
            _tab(Icons.settings_outlined, 'Settings'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProfileTab(),
              _buildLoyaltyTab(),
              _buildFavoritesTab(),
              _buildAddressesTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
      ]),
    );
  }

  Tab _tab(IconData icon, String label) => Tab(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      );

  // ═══════════════════════════════════════════════════════════
  //  TAB 1 — PROFILE
  // ═══════════════════════════════════════════════════════════
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6600), Color(0xFFFF8C42)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Stack(alignment: Alignment.bottomRight, children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 44, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_outlined,
                    size: 14, color: Color(0xFFFF6600)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              _nameCtrl.text.trim().isEmpty ? 'Guest User' : _nameCtrl.text.trim(),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(_emailCtrl.text.trim(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
            if (_phoneCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(_phoneCtrl.text.trim(),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text('$_loyaltyPoints pts',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        _inputField('Full Name', _nameCtrl),
        const SizedBox(height: 14),
        _inputField('Email Address', _emailCtrl,
            type: TextInputType.emailAddress, readOnly: true),
        const SizedBox(height: 14),
        _phoneField(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE0CC)),
          ),
          child: Row(children: [
            const Icon(Icons.card_giftcard, color: Color(0xFFFF6600)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Referral Code',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(_referralCode,
                    style: const TextStyle(
                        color: Color(0xFFFF6600),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                const Text('Share & earn 50 pts per friend',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Color(0xFFFF6600)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _referralCode));
                _snack('Referral code copied!');
              },
            ),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) {
                _snack('Name cannot be empty', bg: Colors.red);
                return;
              }
              AuthService.instance
                  .updateProfile(name: name, phone: _phoneCtrl.text.trim());
              _snack('Profile updated!', bg: Colors.green);
            },
            child: const Text('Save Changes',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(context);
                        await AuthService.instance.logout();
                        if (!mounted) return;
                        // Close the dialog + sheet, then land on the
                        // role select screen with a cleared stack.
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/role-select', (route) => false);
                      },
                      child: const Text('Sign Out',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, bool readOnly = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1D26))),
      const SizedBox(height: 7),
      TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: readOnly,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6600), width: 1.5)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    ]);
  }

  Widget _phoneField() {
    final phone = _phoneCtrl.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Phone Number',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1D26))),
      const SizedBox(height: 7),
      GestureDetector(
        onTap: _showEditPhoneDialog,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                phone.isEmpty ? 'Add phone number' : phone,
                style: TextStyle(
                    fontSize: 15,
                    color: phone.isEmpty ? Colors.grey.shade400 : const Color(0xFF1A1D26)),
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFFF6600)),
          ]),
        ),
      ),
    ]);
  }

  void _showEditPhoneDialog() {
    final ctrl = TextEditingController(text: _phoneCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Phone Number', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '09XXXXXXXXX',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
            onPressed: () async {
              final phone = ctrl.text.trim();
              if (phone.isEmpty) {
                _snack('Phone number cannot be empty', bg: Colors.red);
                return;
              }
              Navigator.pop(ctx);
              await AuthService.instance.updatePhone(phone);
              if (!mounted) return;
              setState(() => _phoneCtrl.text = phone);
              _snack('Phone number saved!', bg: Colors.green);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB 2 — LOYALTY
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoyaltyTab() {
    const int nextTier = 500;
    final double progress = (_loyaltyPoints / nextTier).clamp(0.0, 1.0);
    final String tier = _loyaltyPoints >= 500
        ? 'Gold'
        : _loyaltyPoints >= 200
            ? 'Silver'
            : 'Bronze';
    final Color tierColor = tier == 'Gold'
        ? Colors.amber
        : tier == 'Silver'
            ? Colors.blueGrey
            : const Color(0xFFCD7F32);

    final List<Map<String, dynamic>> rewards = [
      {'title': 'Free Delivery', 'pts': 100, 'icon': Icons.delivery_dining},
      {'title': '\u20B15 Voucher',   'pts': 200, 'icon': Icons.card_giftcard},
      {'title': '\u20B110 Voucher',  'pts': 400, 'icon': Icons.local_offer},
      {'title': 'Free Dessert',  'pts': 150, 'icon': Icons.cake},
      {'title': '20% Off Order', 'pts': 300, 'icon': Icons.percent},
    ];

    final List<Map<String, dynamic>> history = _pointsHistory();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tierColor.withValues(alpha: 0.9), tierColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
            const SizedBox(height: 8),
            Text('$tier Member',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$_loyaltyPoints',
                style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1)),
            const Text('POINTS',
                style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text('${(nextTier - _loyaltyPoints).clamp(0, nextTier)} pts to next tier',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Redeem Rewards'),
        const SizedBox(height: 12),

        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: rewards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final r = rewards[i];
              final canRedeem = _loyaltyPoints >= (r['pts'] as int);
              return GestureDetector(
                onTap: canRedeem
                    ? () => _showRedeemDialog(r)
                    : () => _snack('Not enough points', bg: Colors.grey),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canRedeem ? const Color(0xFFFFF7F0) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: canRedeem ? const Color(0xFFFFE0CC) : Colors.grey.shade200),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(r['icon'] as IconData,
                        color: canRedeem ? const Color(0xFFFF6600) : Colors.grey, size: 24),
                    const SizedBox(height: 6),
                    Text(r['title'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: canRedeem ? Colors.black : Colors.grey),
                        textAlign: TextAlign.center, maxLines: 2),
                    const SizedBox(height: 4),
                    Text('${r['pts']} pts',
                        style: TextStyle(
                            fontSize: 11,
                            color: canRedeem ? const Color(0xFFFF6600) : Colors.grey,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Points History'),
        const SizedBox(height: 12),

        if (history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12)),
            child: const Text(
                'No points yet — you earn 1 point for every ₱1 spent on delivered orders.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ...history.map((h) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (h['add'] as bool)
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (h['add'] as bool) ? Icons.add : Icons.remove,
                    size: 14,
                    color: (h['add'] as bool) ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h['desc'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(h['date'] as String,
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                ),
                Text(h['pts'] as String,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: (h['add'] as bool) ? Colors.green : Colors.red)),
              ]),
            )),
      ]),
    );
  }

  List<Map<String, dynamic>> _pointsHistory() {
    final email = AuthService.instance.currentEmail;
    if (email == null) return [];
    final delivered = AppData.instance
        .ordersForCustomer(email)
        .where((o) => o.status == OrderStatus.delivered)
        .toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return [
      for (final o in delivered)
        {
          'desc': 'Order ${o.id}',
          'pts': '+${o.total.floor()}',
          'date': _friendlyDate(o.placedAt),
          'add': true,
        },
    ];
  }

  String _friendlyDate(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[when.month - 1]} ${when.day}, ${when.year}';
  }

  void _showRedeemDialog(Map<String, dynamic> reward) {
    final title = reward['title'] as String;
    final pts = reward['pts'] as int;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Redeem $title', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Your points are earned automatically — ₱1 spent on every delivered '
          'order equals 1 point — so redeeming never reduces your balance.\n\n'
          'This reward ($pts pts) will be recorded as a promo and applied to '
          'your next order.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
            onPressed: () {
              Navigator.pop(ctx);
              _snack('$title will be applied to your next order!',
                  bg: Colors.green);
            },
            child: const Text('Apply to Next Order',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB 3 — FAVORITES
  // FIX: "Order Now" now properly calls back to HomePage cart logic
  // ═══════════════════════════════════════════════════════════
  Widget _buildFavoritesTab() {
    final favs = _favorites;

    if (favs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No favorites yet',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tap the ❤ on a restaurant to save it here',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (_, i) {
        final r = favs[i];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              // FIX: load first menu image for the restaurant
              Builder(builder: (_) {
                final List items = restaurantMenus[r['name']] ?? [];
                final String imgUrl =
                    items.isNotEmpty ? (items.first['image'] ?? '') : '';
                return ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: imgUrl.isNotEmpty
                        ? Image.asset(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade100,
                              child: Icon(Icons.fastfood_rounded,
                                  color:
                                      Colors.orange.withValues(alpha: 0.4),
                                  size: 36),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade100,
                            child: Icon(Icons.fastfood_rounded,
                                color: Colors.orange.withValues(alpha: 0.4),
                                size: 36),
                          ),
                  ),
                );
              }),
              // Unfavorite button
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: () {
                    widget.onToggleFavorite(r['name']!);
                    setState(() {});
                    _snack('Removed from favorites');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_rounded,
                        color: Color(0xFFFF6600), size: 16),
                  ),
                ),
              ),
              // Rating badge
              Positioned(
                bottom: 6, left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, color: Colors.orange, size: 12),
                    const SizedBox(width: 2),
                    Text(r['rating'] ?? '0.0',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.orange)),
                  ]),
                ),
              ),
            ]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(r['tags'] ?? '',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 11, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text('${r['prep']} min',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ]),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: OutlinedButton(
                      // Opens the restaurant menu; ordering happens per item.
                      onPressed: () => openRestaurantMenu(
                        context,
                        r,
                        widget.onOrderFromFavorites,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6600),
                        side: const BorderSide(
                            color: Color(0xFFFF6600), width: 1.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Menu',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB 4 — ADDRESSES
  // ═══════════════════════════════════════════════════════════
  Widget _buildAddressesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GestureDetector(
          onTap: _showAddAddressDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF6600), width: 1.5),
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFFFF7F0),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_location_alt_outlined, color: Color(0xFFFF6600), size: 20),
              SizedBox(width: 8),
              Text('Add New Address',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFFFF6600))),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        ..._addresses.asMap().entries.map((entry) {
          final i = entry.key;
          final addr = entry.value;
          final isDefault = addr['isDefault'] == 'true';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDefault ? const Color(0xFFFFF7F0) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDefault ? const Color(0xFFFF6600) : Colors.transparent,
                  width: 1.5),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDefault
                      ? const Color(0xFFFF6600).withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  addr['label'] == 'Home'
                      ? Icons.home_outlined
                      : addr['label'] == 'Work'
                          ? Icons.work_outline
                          : Icons.location_on_outlined,
                  color: isDefault ? const Color(0xFFFF6600) : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(addr['label'] ?? 'Address',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF6600),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Default',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(addr['address'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  if (!isDefault) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final chosen = _addresses[i]['address']!;
                        setState(() {
                          for (var a in _addresses) {
                            a['isDefault'] = 'false';
                          }
                          _addresses[i]['isDefault'] = 'true';
                          _addresses[i]['saved'] = 'true';
                        });
                        // Re-add so AuthService.defaultAddress (last added)
                        // matches the chosen default.
                        await AuthService.instance.removeAddress(chosen);
                        await AuthService.instance.addAddress(chosen);
                        if (!mounted) return;
                        widget.onUpdateAddress(chosen);
                        _snack('Default address updated');
                      },
                      child: const Text('Set as default',
                          style: TextStyle(
                              color: Color(0xFFFF6600),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ),
              Column(children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: Colors.grey.shade500,
                  onPressed: () => _showEditAddressDialog(i),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red.shade300,
                  onPressed: () async {
                    final removed = _addresses[i];
                    setState(() => _addresses.removeAt(i));
                    if (removed['saved'] == 'true') {
                      await AuthService.instance
                          .removeAddress(removed['address']!);
                    }
                    if (!mounted) return;
                    if (removed['isDefault'] == 'true' &&
                        _addresses.isNotEmpty) {
                      final fallback = _addresses.last;
                      setState(() => fallback['isDefault'] = 'true');
                      widget.onUpdateAddress(fallback['address']!);
                    }
                    _snack('Address removed');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ]),
          );
        }),
      ],
    );
  }

  void _showAddAddressDialog() {
    final labelCtrl = TextEditingController();
    final addrCtrl  = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: labelCtrl,
            decoration: InputDecoration(
                labelText: 'Label (Home, Work, etc.)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addrCtrl,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: 'Full Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 10),
          Text(
            'Tip: allow location access so we can use your device location '
            'to speed up delivery.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
            onPressed: () async {
              final addr = addrCtrl.text.trim();
              if (addr.isEmpty) {
                _snack('Please enter a full address', bg: Colors.red);
                return;
              }
              if (_addresses.any((a) => a['address'] == addr)) {
                _snack('This address is already saved', bg: Colors.red);
                return;
              }
              final label = labelCtrl.text.trim().isEmpty
                  ? 'Address'
                  : labelCtrl.text.trim();
              Navigator.pop(ctx);
              await AuthService.instance.addAddress(addr);
              if (!mounted) return;
              setState(() {
                for (var a in _addresses) {
                  a['isDefault'] = 'false';
                }
                _addresses.add({
                  'label': label,
                  'address': addr,
                  'isDefault': 'true',
                  'saved': 'true',
                });
              });
              widget.onUpdateAddress(addr);
              _snack('Address added & set as default', bg: Colors.green);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(int index) {
    final labelCtrl = TextEditingController(text: _addresses[index]['label']);
    final addrCtrl  = TextEditingController(text: _addresses[index]['address']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Address', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: labelCtrl,
            decoration: InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addrCtrl,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: 'Full Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
            onPressed: () async {
              final oldAddr = _addresses[index]['address']!;
              final newAddr = addrCtrl.text.trim().isEmpty
                  ? oldAddr
                  : addrCtrl.text.trim();
              final newLabel = labelCtrl.text.trim().isEmpty
                  ? _addresses[index]['label']!
                  : labelCtrl.text.trim();
              final wasDefault = _addresses[index]['isDefault'] == 'true';
              Navigator.pop(ctx);
              if (newAddr != oldAddr) {
                await AuthService.instance.removeAddress(oldAddr);
                await AuthService.instance.addAddress(newAddr);
                if (!wasDefault) {
                  final defIndex = _addresses
                      .indexWhere((a) => a['isDefault'] == 'true');
                  if (defIndex >= 0 && defIndex != index) {
                    final def = _addresses[defIndex]['address']!;
                    await AuthService.instance.removeAddress(def);
                    await AuthService.instance.addAddress(def);
                  }
                }
              }
              if (!mounted) return;
              setState(() {
                _addresses[index] = {
                  ..._addresses[index],
                  'label': newLabel,
                  'address': newAddr,
                  'saved': newAddr != oldAddr || _addresses[index]['saved'] == 'true'
                      ? 'true'
                      : 'false',
                };
                if (wasDefault) widget.onUpdateAddress(newAddr);
              });
              _snack('Address updated', bg: Colors.green);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB 5 — SETTINGS
  // ═══════════════════════════════════════════════════════════
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Notifications'),
        const SizedBox(height: 10),
        _switchTile(
          icon: Icons.receipt_long_outlined, iconColor: const Color(0xFFFF6600),
          title: 'Order Updates', subtitle: 'Status changes for your orders',
          value: _notifOrders, onChanged: (v) => setState(() => _notifOrders = v),
        ),
        _switchTile(
          icon: Icons.local_shipping_outlined, iconColor: Colors.blue,
          title: 'Delivery Alerts', subtitle: 'When your rider is nearby',
          value: _notifDelivery, onChanged: (v) => setState(() => _notifDelivery = v),
        ),
        _switchTile(
          icon: Icons.local_offer_outlined, iconColor: Colors.purple,
          title: 'Promos & Offers', subtitle: 'Exclusive deals and discounts',
          value: _notifPromos, onChanged: (v) => setState(() => _notifPromos = v),
        ),
        _switchTile(
          icon: Icons.email_outlined, iconColor: Colors.teal,
          title: 'Email Newsletter', subtitle: 'Weekly deals sent to your email',
          value: _notifEmail, onChanged: (v) => setState(() => _notifEmail = v),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Payment Methods'),
        const SizedBox(height: 10),
        ..._payments.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final isDefault = p['isDefault'] == 'true';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDefault ? const Color(0xFFFFF7F0) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDefault ? const Color(0xFFFF6600) : Colors.transparent,
                  width: 1.5),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDefault
                      ? const Color(0xFFFF6600).withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  p['type'] == 'GCash' || p['type'] == 'Maya' || p['type'] == 'PayMaya'
                      ? Icons.account_balance_wallet_outlined
                      : p['type'] == 'Cash on Delivery'
                          ? Icons.money_outlined
                          : Icons.credit_card_outlined,
                  color: isDefault ? const Color(0xFFFF6600) : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['type']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(p['detail']!,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ]),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF6600),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Default',
                      style: TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var pm in _payments) {
                        pm['isDefault'] = 'false';
                      }
                      _payments[i]['isDefault'] = 'true';
                      widget.onUpdatePayment(_payments[i]['type']!);
                    });
                    _snack('Default payment updated');
                  },
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Set default',
                      style: TextStyle(color: Color(0xFFFF6600), fontSize: 12)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red.shade300,
                padding: const EdgeInsets.only(left: 4),
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final removed = _payments[i];
                  final savedIndex = _payments
                      .take(i)
                      .where((p) => p['saved'] == 'true')
                      .length;
                  final wasDefault = removed['isDefault'] == 'true';
                  setState(() {
                    _payments.removeAt(i);
                    if (wasDefault && _payments.isNotEmpty) {
                      _payments[0]['isDefault'] = 'true';
                      widget.onUpdatePayment(_payments[0]['type']!);
                    }
                  });
                  if (removed['saved'] == 'true') {
                    await AuthService.instance.removePaymentMethod(savedIndex);
                  }
                  if (!mounted) return;
                  _snack('${removed['type']} removed');
                },
              ),
            ]),
          );
        }),
        GestureDetector(
          onTap: _showAddPaymentDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('Add Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Account'),
        const SizedBox(height: 10),
        _actionTile(Icons.lock_outline, 'Change Password',
            Colors.grey.shade700, _showChangePasswordDialog),
        _actionTile(Icons.help_outline, 'Help & Support',
            Colors.grey.shade700, _showSupportDialog),
        _actionTile(Icons.privacy_tip_outlined, 'Privacy Policy',
            Colors.grey.shade700, _showPrivacyPolicyDialog),
        _actionTile(Icons.delete_outline, 'Delete Account', Colors.red,
            _showDeleteAccountDialog),

        const SizedBox(height: 12),
        Center(child: Text('FoodHub v1.0.0',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _switchTile({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ]),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: const Color(0xFFFF6600)),
      ]),
    );
  }

  Widget _actionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title,
              style: TextStyle(fontWeight: FontWeight.w600, color: color))),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1D26)));

  void _showAddPaymentDialog() {
    String selected = 'GCash';
    final detailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...['GCash', 'Maya', 'Cash on Delivery']
                  .map((opt) => RadioListTile<String>(
                        title: Text(opt),
                        value: opt,
                        groupValue: selected,
                        activeColor: const Color(0xFFFF6600),
                        onChanged: (v) => setD(() => selected = v!),
                        contentPadding: EdgeInsets.zero,
                      )),
              const SizedBox(height: 8),
              TextField(
                controller: detailCtrl,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: selected == 'Cash on Delivery'
                      ? 'Note (optional)'
                      : 'Account number',
                  hintText: selected == 'Cash on Delivery'
                      ? 'e.g. Pay upon delivery'
                      : 'e.g. 09171234567',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
              onPressed: () async {
                var detail = detailCtrl.text.trim();
                if (selected != 'Cash on Delivery' && detail.isEmpty) {
                  _snack('Please enter your account number', bg: Colors.red);
                  return;
                }
                if (detail.isEmpty) detail = 'Pay upon delivery';
                Navigator.pop(ctx);
                await AuthService.instance
                    .addPaymentMethod(label: selected, details: detail);
                if (!mounted) return;
                setState(() => _payments.add({
                  'type': selected,
                  'detail': detail,
                  'isDefault': 'false',
                  'saved': 'true',
                }));
                _snack('$selected added', bg: Colors.green);
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: currentCtrl,
            obscureText: true,
            decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newCtrl,
            obscureText: true,
            decoration: InputDecoration(
                labelText: 'New Password',
                hintText: 'At least 6 characters',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmCtrl,
            obscureText: true,
            decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
            onPressed: () async {
              final current = currentCtrl.text;
              final newPass = newCtrl.text;
              final confirm = confirmCtrl.text;
              if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                _snack('Please fill in all fields', bg: Colors.red);
                return;
              }
              if (newPass.length < 6) {
                _snack('New password must be at least 6 characters',
                    bg: Colors.red);
                return;
              }
              if (newPass != confirm) {
                _snack('New passwords do not match', bg: Colors.red);
                return;
              }
              if (newPass == current) {
                _snack('New password must differ from current password',
                    bg: Colors.red);
                return;
              }
              final error = await AuthService.instance.changePassword(
                  currentPassword: current, newPassword: newPass);
              if (!mounted) return;
              if (error != null) {
                _snack(error, bg: Colors.red);
                return;
              }
              Navigator.pop(context);
              _snack('Password changed successfully!', bg: Colors.green);
            },
            child: const Text('Change Password',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('We are here to help — reach us any time through these channels:',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          _supportOption(
            icon: Icons.phone_outlined,
            title: 'Call us',
            subtitle: '+63 912 345 6789',
            onTap: () => _launch('tel:+639123456789'),
          ),
          const SizedBox(height: 10),
          _supportOption(
            icon: Icons.email_outlined,
            title: 'Email us',
            subtitle: 'support@foodhub.app',
            onTap: () => _launch('mailto:support@foodhub.app'),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE0CC)),
            ),
            child: const Text(
              'Customer support hours:\nMonday – Sunday, 8:00 AM – 10:00 PM (PHT)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _supportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFFF6600).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFFFF6600), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ]),
          ),
          Icon(Icons.open_in_new, size: 16, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      _snack('Could not open $url', bg: Colors.red);
    }
  }

  void _showPrivacyPolicyDialog() {
    const sections = [
      (
        '1. Information We Collect',
        'When you create a FoodHub account we collect your name, email '
            'address, and password (stored only as a secure hash). Optionally, '
            'you may add a phone number, saved delivery addresses, and payment '
            'method labels such as GCash or Maya account numbers that you type '
            'in yourself.'
      ),
      (
        '2. Location Data',
        'With your permission, we access your device location while you are '
            'placing or tracking an order so the assigned rider can find you '
            'quickly. Location is never collected in the background and is '
            'only shared while an order is in progress.'
      ),
      (
        '3. How We Use Your Information',
        'We use your details to create and secure your account, process and '
            'deliver orders, show your order history and loyalty points, and '
            'send you optional notifications about order status and promos '
            'you have opted into.'
      ),
      (
        '4. Order Information Shared with Partners',
        'To complete a delivery we share only what is necessary — your '
            'delivery address, contact number, and order contents — with the '
            'restaurant preparing your food and the rider assigned to your '
            'order. We do not sell this information.'
      ),
      (
        '5. Payment Information',
        'Payment method details you save (such as a GCash or Maya account '
            'number) are used solely to indicate your preferred way to pay. '
            'Card and wallet credentials are not stored on our servers beyond '
            'the label and last details you chose to keep on file.'
      ),
      (
        '6. Loyalty Points and Referrals',
        'We record the total peso amount of your delivered orders to '
            'calculate loyalty points and we keep a referral code tied to '
            'your account so friends who sign up through it can be matched '
            'to your profile for reward purposes.'
      ),
      (
        '7. Notifications',
        'If you enable order, delivery, promo, or email notifications in '
            'Settings, we use the contact details on file to send those '
            'messages. You can turn any of them off at any time from your '
            'profile.'
      ),
      (
        '8. Data Retention',
        'We keep your account data for as long as your account is active so '
            'your history, addresses, and points remain available. Deleting '
            'your account from Settings permanently removes your cloud '
            'profile, order association, and every local record on this '
            'device.'
      ),
      (
        '9. Data Security',
        'Passwords are never stored in plain text. Account records are '
            'protected by Firebase Authentication and secured database '
            'rules, and traffic between the app and our services is encrypted '
            'in transit.'
      ),
      (
        '10. Children',
        'FoodHub is intended for users aged 13 and older. We do not '
            'knowingly collect personal information from children. If we '
            'learn that a child has provided us data, we will delete it '
            'promptly.'
      ),
      (
        '11. Your Choices and Rights',
        'You may review and edit your name, phone, addresses, and payment '
            'methods directly in the app, opt out of notifications at any '
            'time, and delete your account whenever you wish. You may also '
            'request a copy or correction of your data by contacting us.'
      ),
      (
        '12. Changes to This Policy',
        'We may update this policy as the app evolves. Material changes will '
            'be announced in-app. Continued use of FoodHub after an update '
            'means you accept the revised policy.'
      ),
      (
        '13. Contact Us',
        'Questions about this policy or your data? Email us at '
            'support@foodhub.app or call +63 912 345 6789, Monday to Sunday, '
            '8:00 AM to 10:00 PM (PHT).'
      ),
    ];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Privacy Policy',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                CloseButton(),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Your privacy matters to us. This policy explains what FoodHub '
                  'collects, why we collect it, and the control you have over '
                  'your information.',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                for (final s in sections) ...[
                  Text(s.$1,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(s.$2,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.5)),
                  const SizedBox(height: 14),
                ],
                Text('Last updated: January 2026',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'This permanently deletes your FoodHub account and cannot be '
            'undone. The following will be removed:',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
          _deleteBullet('Your profile, name, and phone number'),
          _deleteBullet('All saved addresses and payment methods'),
          _deleteBullet('Your order history and loyalty points'),
          _deleteBullet('Your cloud account and every local record on this device'),
          const SizedBox(height: 14),
          TextField(
            controller: passCtrl,
            obscureText: true,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
                labelText: 'Enter your password to confirm',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final password = passCtrl.text;
              if (password.isEmpty) {
                _snack('Please enter your password', bg: Colors.red);
                return;
              }
              Navigator.pop(ctx);
              final error =
                  await AuthService.instance.deleteAccount(password: password);
              if (!mounted) return;
              if (error != null) {
                _snack(error, bg: Colors.red);
                return;
              }
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/role-select', (route) => false);
            },
            child: const Text('Delete Forever', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _deleteBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.close_rounded, size: 16, color: Colors.red),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ]),
    );
  }
}