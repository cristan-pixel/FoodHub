// lib/screens/role_select_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/widgets/app_logo.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F3),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFF0EEE6)),
                  ),
                  child: const AppLogo(size: 96),
                ),
              ),
              const SizedBox(height: 24),
              const Text('FoodHub',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Continue as...',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),
              _roleCard(
                context,
                icon: Icons.restaurant_menu,
                title: 'Order Food',
                subtitle: 'Browse restaurants & order as a customer',
                route: '/login',
              ),
              _roleCard(
                context,
                icon: Icons.two_wheeler,
                title: 'Deliver Orders',
                subtitle: 'Sign in as a rider and start delivering',
                route: '/rider/login',
              ),
              _roleCard(
                context,
                icon: Icons.storefront,
                title: 'Restaurant Partner',
                subtitle: 'Manage incoming orders and your menu',
                route: '/restaurant/login',
              ),
              _roleCard(
                context,
                icon: Icons.admin_panel_settings,
                title: 'Admin',
                subtitle: 'Operations overview & live order map',
                route: '/admin/login',
                dark: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    bool dark = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1A1D26) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color:
                    dark ? const Color(0xFF1A1D26) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6600),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: dark ? Colors.white60 : Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: dark ? Colors.white54 : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
