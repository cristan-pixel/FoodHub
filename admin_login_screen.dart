// lib/screens/admin/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/services/admin_auth_service.dart';
import 'package:foodhub1/widgets/app_logo.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'admin@foodhub.com');
  final _passwordCtrl = TextEditingController(text: 'admin123');
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final err = await AdminAuthService.instance
        .login(email: _emailCtrl.text, password: _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pushReplacementNamed('/admin/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D26),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/role-select'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 92,
                      height: 92,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F3),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const AppLogo(size: 74),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Admin Login',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('Operations overview & live order map',
                      style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white60),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white60),
                      enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white60),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 12),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Sign In',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
