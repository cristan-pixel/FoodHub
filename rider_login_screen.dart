// lib/screens/rider/rider_login_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/services/rider_auth_service.dart';
import 'package:foodhub1/screens/rider/rider_signup_screen.dart';
import 'package:foodhub1/widgets/app_logo.dart';

class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'jun@foodhub.com');
  final _passwordCtrl = TextEditingController(text: 'rider123');
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final err = await RiderAuthService.instance
        .login(email: _emailCtrl.text, password: _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pushReplacementNamed('/rider/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F0),
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
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/role-select'),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppLogo(size: 92),
                  ),
                  const SizedBox(height: 20),
                  const Text('Rider Login',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Sign in to see delivery requests near you',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  const Text('Demo: jun@foodhub.com / rider123',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RiderSignUpScreen()),
                    ),
                    child: const Text('New rider? Apply here'),
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
