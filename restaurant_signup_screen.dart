// lib/screens/restaurant/restaurant_signup_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/services/restaurant_auth_service.dart';

class RestaurantSignUpScreen extends StatefulWidget {
  const RestaurantSignUpScreen({super.key});

  @override
  State<RestaurantSignUpScreen> createState() =>
      _RestaurantSignUpScreenState();
}

class _RestaurantSignUpScreenState extends State<RestaurantSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final err = await RestaurantAuthService.instance.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      cuisine: _cuisineCtrl.text,
      address: _addressCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pushReplacementNamed('/restaurant/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner With Us'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Restaurant Name', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Business Email', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cuisineCtrl,
                decoration: const InputDecoration(
                    labelText: 'Cuisine (e.g. Italian, Pizza)',
                    border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter cuisine type' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Restaurant Address', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter an address' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Create Restaurant Account',
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
    );
  }
}
