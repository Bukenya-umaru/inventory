import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/app_drawer.dart' show ThemeToggleFab, kWideScreenBreakpoint;
import '../../widgets/download_app_fab.dart';
import '../../utils/theme.dart';

/// Duration the blue splash is shown before revealing the login page.
const Duration _kSplashDuration = Duration(seconds: 2);

/// Accent blue used on splash + login, matching the design mock.
const Color _kBlue = Color(0xFF283593);
const Color _kBlueDark = Color(0xFF1A237E);

/// Logo mark: "Inventory" with three dots above, in accent blue.
class _Wordmark extends StatelessWidget {
  final double fontSize;
  final Color color;

  const _Wordmark({required this.fontSize, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots above the word.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(3, color.withValues(alpha: 0.35)),
            const SizedBox(width: 3),
            _dot(5, color.withValues(alpha: 0.55)),
            const SizedBox(width: 3),
            _dot(7, color),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Inventory',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _dot(double size, Color c) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

/// White page containing the login form. On wide screens the form is
/// presented as a centered card on a light background.
class _LoginFormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool loading;
  final bool obscure;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _LoginFormView({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.loading,
    required this.obscure,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  OutlineInputBorder _border(Color c, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c, width: width),
      );

  Widget _buildForm(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.height < 600;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Center(
            child: _Wordmark(
              fontSize: AppTheme.fontSize(context, isSmall ? 26 : 32),
              color: _kBlue,
            ),
          ),
          SizedBox(height: isSmall ? 28 : 48),

          // Heading
          Text(
            'Login to your Account',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, isSmall ? 16 : 20),
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor(context),
            ),
          ),
          SizedBox(height: isSmall ? 16 : 24),

          if (error != null)
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
                    child: Text(error!,
                      style: TextStyle(color: AppTheme.danger, fontSize: AppTheme.fontSize(context, 13))),
                  ),
                ],
              ),
            ),

          // Email
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: AppTheme.fontSize(context, isSmall ? 13 : 14)),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: AppTheme.fontSize(context, isSmall ? 13 : 14),
              ),
              filled: true,
              fillColor: AppTheme.cardColor(context),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmall ? 12 : 14),
              enabledBorder: _border(Colors.grey.shade300),
              focusedBorder: _border(_kBlue, width: 1.5),
              errorBorder: _border(AppTheme.danger),
              focusedErrorBorder: _border(AppTheme.danger, width: 1.5),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          SizedBox(height: isSmall ? 12 : 16),

          // Password
          TextFormField(
            controller: passCtrl,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            style: TextStyle(fontSize: AppTheme.fontSize(context, isSmall ? 13 : 14)),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: AppTheme.fontSize(context, isSmall ? 13 : 14),
              ),
              filled: true,
              fillColor: AppTheme.cardColor(context),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmall ? 12 : 14),
              enabledBorder: _border(Colors.grey.shade300),
              focusedBorder: _border(_kBlue, width: 1.5),
              errorBorder: _border(AppTheme.danger),
              focusedErrorBorder: _border(AppTheme.danger, width: 1.5),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.secondaryText(context),
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
          SizedBox(height: isSmall ? 18 : 28),

          // Sign in button
          SizedBox(
            width: double.infinity,
            height: isSmall ? 44 : 50,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kBlue.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Sign in',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 14 : 16),
                        fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= kWideScreenBreakpoint;

    if (isWide) {
      // Big screens: centered white card on a light background.
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.surfaceColor(context),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              width: 420,
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 40),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _buildForm(context),
            ),
          ),
        ),
      );
    }

    // Phones & small screens: full white page, footer pinned at the bottom.
    final isSmall = size.height < 600;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.cardColor(context),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                // Top padding keeps the wordmark's dots clear of the
                // status bar / top edge on phones.
                padding: EdgeInsets.fromLTRB(28, isSmall ? 20 : 32, 28, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildForm(context),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        'Contact your administrator for access',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 12),
                          color: AppTheme.secondaryText(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(_kSplashDuration, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
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

  /// Full-screen blue splash with the "Inventory" wordmark.
  Widget _buildSplash(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? _kBlueDark : _kBlue,
      child: Center(
        child: _Wordmark(
          fontSize: 38,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Phones only: the blue flash screen and the download-app button.
    // Tablets, laptops and desktops go straight to the login form and only
    // keep the theme toggle.
    final isPhone = AppTheme.isPhoneScreen(context);
    return Scaffold(
      // Floating dark/light mode toggle — bottom right corner (unchanged,
      // on both splash and login, phone and desktop). The download app button
      // next to it is mobile-only.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ThemeToggleFab(),
          if (isPhone) ...[
            const SizedBox(height: 12),
            const DownloadAppFab(),
          ],
        ],
      ),
      body: (isPhone && _showSplash)
          ? _buildSplash(context)
          : _LoginFormView(
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              passCtrl: _passCtrl,
              loading: _loading,
              obscure: _obscure,
              error: _error,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSubmit: _login,
            ),
    );
  }
}
