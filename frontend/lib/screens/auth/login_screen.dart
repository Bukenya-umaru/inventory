import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final error = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;
    if (error != null) {
      setState(() { _loading = false; _error = error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withValues(alpha: 0.08),
              Colors.white,
              AppTheme.primary.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width < 400 ? 20 : size.width < 800 ? 32 : 40,
                vertical: isSmall ? 16 : 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        padding: EdgeInsets.all(isSmall ? 16 : 24),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.inventory_2_outlined,
                          size: AppTheme.fontSize(context, isSmall ? 36 : 48),
                          color: AppTheme.primary),
                      ),
                      SizedBox(height: isSmall ? 16 : 28),
                      // Title
                      Text('Inventory Management',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, isSmall ? 22 : 28),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                        textAlign: TextAlign.center),
                      SizedBox(height: isSmall ? 4 : 8),
                      Text('Sign in to your account',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, isSmall ? 13 : 16),
                          color: Colors.grey.shade500)),
                      SizedBox(height: isSmall ? 24 : 40),

                      // Error
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!,
                                  style: TextStyle(color: AppTheme.danger, fontSize: AppTheme.fontSize(context, 13))),
                              ),
                            ],
                          ),
                        ),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(fontSize: AppTheme.fontSize(context, isSmall ? 14 : 16)),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 12 : 16),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      SizedBox(height: isSmall ? 12 : 18),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(fontSize: AppTheme.fontSize(context, isSmall ? 14 : 16)),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 12 : 16),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          return null;
                        },
                        onFieldSubmitted: (_) => _login(),
                      ),
                      SizedBox(height: isSmall ? 20 : 32),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: isSmall ? 46 : 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _loading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text('Sign In',
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSize(context, isSmall ? 15 : 18),
                                    fontWeight: FontWeight.w600)),
                        ),
                      ),
                      SizedBox(height: isSmall ? 16 : 24),

                      Text('Contact your administrator for access',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                          color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
