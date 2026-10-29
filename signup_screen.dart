// lib/signup_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:foodhub1/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  String? _errorMsg;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  double get _passwordStrength {
    final p = _passwordCtrl.text;
    if (p.isEmpty) return 0;
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
    return s;
  }

  Color get _strengthColor {
    final s = _passwordStrength;
    if (s <= 0.25) return Colors.red;
    if (s <= 0.5) return Colors.orange;
    if (s <= 0.75) return Colors.amber;
    return Colors.green;
  }

  String get _strengthLabel {
    final s = _passwordStrength;
    if (s == 0) return '';
    if (s <= 0.25) return 'Weak';
    if (s <= 0.5) return 'Fair';
    if (s <= 0.75) return 'Good';
    return 'Strong';
  }

  /// Shows the in-app Terms / Privacy summary instead of a dead link.
  void _showPolicyDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignUp() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      setState(() =>
          _errorMsg = 'Please agree to the Terms & Privacy Policy.');
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final error = await AuthService.instance.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }

    // ── Success: pop back to LoginScreen and pass the registered email ──
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Account created! Please sign in. 🎉',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    // Return the email so LoginScreen can pre-fill it
    Navigator.of(context).pop(_emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 20, color: Color(0xFF1A1D26)),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Create account 🚀',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1D26),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join FoodHub and start ordering today',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade500),
                  ),

                  const SizedBox(height: 28),

                  // Error banner
                  if (_errorMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMsg!,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Full Name'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _nameCtrl,
                          hint: 'John Doe',
                          prefixIcon: Icons.person_outline,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        _buildLabel('Email Address'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailCtrl,
                          hint: 'you@email.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!v.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        _buildLabel('Phone Number'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _phoneCtrl,
                          hint: '+63 912 345 6789',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        _buildLabel('Password'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordCtrl,
                          hint: 'Min. 6 characters',
                          prefixIcon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          onChanged: (_) => setState(() {}),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        if (_passwordCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: _passwordStrength,
                                  minHeight: 5,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          _strengthColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _strengthLabel,
                              style: TextStyle(
                                  color: _strengthColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ],

                        const SizedBox(height: 18),

                        _buildLabel('Confirm Password'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _confirmCtrl,
                          hint: '••••••••',
                          prefixIcon: Icons.lock_outline,
                          obscure: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: () => setState(
                              () => _agreeToTerms = !_agreeToTerms),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(top: 2),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _agreeToTerms
                                      ? const Color(0xFFFF6600)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: _agreeToTerms
                                        ? const Color(0xFFFF6600)
                                        : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                child: _agreeToTerms
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 13)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                        height: 1.4),
                                    children: [
                                      const TextSpan(
                                          text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: const TextStyle(
                                          color: Color(0xFFFF6600),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _showPolicyDialog(
                                              'Terms of Service',
                                              'By using FoodHub you agree to '
                                                  'order responsibly and pay '
                                                  'for your orders on time. '
                                                  'Restaurant partners and '
                                                  'riders must operate within '
                                                  'their local delivery area '
                                                  'and follow food-safety '
                                                  'practices.'),
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: const TextStyle(
                                          color: Color(0xFFFF6600),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _showPolicyDialog(
                                              'Privacy Policy',
                                              'FoodHub stores only the '
                                                  'information needed to '
                                                  'deliver your orders: your '
                                                  'name, email, phone, '
                                                  'delivery address, and '
                                                  'order history. We never '
                                                  'sell your data. GPS '
                                                  'location is used only '
                                                  'while a rider is delivering '
                                                  'to you.'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6600),
                              disabledBackgroundColor:
                                  const Color(0xFFFF6600)
                                      .withValues(alpha: 0.6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                              shadowColor: const Color(0xFFFF6600)
                                  .withValues(alpha: 0.4),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Color(0xFFFF6600),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF1A1D26)),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1D26)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon:
            Icon(prefixIcon, color: Colors.grey.shade400, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFF6600), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}