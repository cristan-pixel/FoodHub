// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:foodhub1/auth_service.dart';
import 'package:foodhub1/signup_screen.dart';
import 'package:foodhub1/services/social_auth_service.dart';
import 'package:foodhub1/widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMsg;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Runs a social sign-in provider. Calls [action], which returns an error
  /// message (or null on success), then routes to /home on success. A
  /// provider that returns null without signing anybody in (the user
  /// closed the account chooser) must not navigate.
  Future<void> _handleSocial(Future<String?> Function() action) async {
    setState(() => _errorMsg = null);
    setState(() => _isLoading = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }
    if (!AuthService.instance.isLoggedIn) return; // cancelled
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    if (!mounted) return;

    final error = await AuthService.instance.login(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMsg = error);
      return;
    }

    // ── Logged in — go to home and clear back-stack ──
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  /// Opens SignUpScreen and waits for it to pop.
  /// If sign-up succeeded it pops with the registered email string,
  /// so we pre-fill it here for a smooth UX.
  Future<void> _goToSignUp() async {
    final registeredEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
    if (registeredEmail != null && registeredEmail.isNotEmpty && mounted) {
      _emailCtrl.text = registeredEmail;
      _passwordCtrl.clear();
      setState(() => _errorMsg = null);
    }
  }

  /// Sends a real Firebase password-reset email to the typed address.
  void _showForgotPasswordDialog() {
    final controller = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reset Password',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email and we will send you a link to set a new '
              'password.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
            ),
            onPressed: () async {
              final email = controller.text.trim();
              Navigator.pop(dialogContext);
              if (email.isEmpty || !email.contains('@')) {
                setState(() => _errorMsg = 'Enter a valid email address.');
                return;
              }
              final error = await AuthService.instance.sendPasswordReset(email);
              if (!mounted) return;
              setState(() => _errorMsg = error);
              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset email sent to $email.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
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
                  const SizedBox(height: 40),

                  // ── Brand header ─────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF9F3),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6600)
                                    .withValues(alpha: 0.22),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const AppLogo(size: 82),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'FoodHub',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF6600),
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your favourite food, delivered fast',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 44),

                  const Text(
                    'Welcome back 👋',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1D26),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue ordering',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
                      children: [
                        // Email
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
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Password
                        _buildLabel('Password'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordCtrl,
                          hint: '••••••••',
                          prefixIcon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Remember me + Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: Row(children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: _rememberMe
                                        ? const Color(0xFFFF6600)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: _rememberMe
                                          ? const Color(0xFFFF6600)
                                          : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _rememberMe
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 13)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text('Remember me',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13)),
                              ]),
                            ),
                            GestureDetector(
                              onTap: () => _showForgotPasswordDialog(),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: Color(0xFFFF6600),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Sign In button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6600),
                              disabledBackgroundColor: const Color(0xFFFF6600)
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
                                    'Sign In',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(children: [
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or continue with',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                        ]),

                        const SizedBox(height: 20),

                        Row(children: [
                          Expanded(
                            child: _socialButton(
                              label: 'Google',
                              icon: Icons.g_mobiledata_rounded,
                              onTap: () => _handleSocial(() => SocialAuthService
                                  .instance
                                  .signInWithGoogle()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _socialButton(
                              label: 'Facebook',
                              icon: Icons.facebook_rounded,
                              onTap: () => _handleSocial(() => SocialAuthService
                                  .instance
                                  .signInWithFacebook()),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 36),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ",
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 14)),
                            GestureDetector(
                              onTap: _goToSignUp,
                              child: const Text(
                                'Sign Up',
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

  Widget _buildLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF1A1D26)),
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1D26)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400, size: 20),
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
          borderSide: const BorderSide(color: Color(0xFFFF6600), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF1A1D26)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1A1D26))),
          ],
        ),
      ),
    );
  }
}
