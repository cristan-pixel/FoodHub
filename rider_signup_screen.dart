// lib/screens/rider/rider_signup_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/services/rider_auth_service.dart';

class RiderSignUpScreen extends StatefulWidget {
  const RiderSignUpScreen({super.key});

  @override
  State<RiderSignUpScreen> createState() => _RiderSignUpScreenState();
}

class _RiderSignUpScreenState extends State<RiderSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _vehicle = 'Motorcycle';
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final err = await RiderAuthService.instance.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      vehicle: _vehicle,
    );
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
      appBar: AppBar(
        title: const Text('Rider Application'),
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
                    labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
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
              DropdownButtonFormField<String>(
                value: _vehicle,
                decoration: const InputDecoration(
                    labelText: 'Vehicle', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'Motorcycle', child: Text('Motorcycle')),
                  DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
                  DropdownMenuItem(value: 'Car', child: Text('Car')),
                  DropdownMenuItem(
                      value: 'On Foot', child: Text('On Foot')),
                ],
                onChanged: (v) => setState(() => _vehicle = v ?? 'Motorcycle'),
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
                      : const Text('Create Rider Account',
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
