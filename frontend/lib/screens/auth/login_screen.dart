import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/app_drawer.dart' show ThemeToggleFab;
import '../../widgets/download_app_fab.dart';
import '../../utils/theme.dart';

/// Duration the blue splash is shown before revealing the login page.
const Duration _kSplashDuration = Duration(seconds: 2);

/// Brand palette for splash + login, matching the Inventar design:
/// deep charcoal page background with a vivid green card header.
const Color _kGreenTop = Color(0xFF189048);
const Color _kGreenBottom = Color(0xFF30D878);
const Color _kPageTop = Color(0xFF0C1112);
const Color _kPageBottom = Color(0xFF141E22);
const Color _kPageTopDark = Color(0xFF080B0C);
const Color _kPageBottomDark = Color(0xFF0F171B);

const LinearGradient _kBlueGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_kGreenTop, _kGreenBottom],
);

/// Logo square + "Inventory" wordmark + tagline. Shown on the login card
/// header and on the phone splash.
class _BrandHeader extends StatelessWidget {
  final double iconSize;
  final double nameSize;
  final double taglineSize;

  const _BrandHeader({
    required this.iconSize,
    required this.nameSize,
    required this.taglineSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Frosted rounded-square holding the boxes logo.
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(iconSize * 0.28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.view_in_ar,
            size: iconSize * 0.55,
            color: Colors.white,
          ),
        ),
        SizedBox(height: iconSize * 0.22),
        Text(
          'Inventory',
          style: TextStyle(
            color: Colors.white,
            fontSize: nameSize,
            fontWeight: FontWeight.w800,
            letterSpacing: nameSize * 0.08,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Smart Inventory, Total Control',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: taglineSize,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Gradient page with the centered login card: blue brand header on top and
/// the white "Welcome back" form below.
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
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: width),
      );

  Widget _fieldLabel(BuildContext context, String text, bool isSmall) => Text(
        text,
        style: TextStyle(
          fontSize: AppTheme.fontSize(context, isSmall ? 11.5 : 13),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: AppTheme.secondaryText(context),
        ),
      );

  Widget _buildForm(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.height < 600;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            'Welcome back',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, isSmall ? 22 : 26),
              fontWeight: FontWeight.w800,
              color: AppTheme.textColor(context),
              height: 1.1,
            ),
          ),
          SizedBox(height: isSmall ? 14 : 22),

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
          _fieldLabel(context, 'EMAIL ADDRESS', isSmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              color: AppTheme.textColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'name@gmail.com',
              hintStyle: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              ),
              filled: true,
              fillColor: AppTheme.cardColor(context),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmall ? 14 : 16),
              prefixIcon: Icon(
                Icons.mail_outline,
                color: AppTheme.secondaryText(context),
                size: 20,
              ),
              enabledBorder: _border(AppTheme.borderColor(context)),
              focusedBorder: _border(_kGreenBottom, width: 1.5),
              errorBorder: _border(AppTheme.danger),
              focusedErrorBorder: _border(AppTheme.danger, width: 1.5),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          SizedBox(height: isSmall ? 14 : 20),

          // Password
          _fieldLabel(context, 'PASSWORD', isSmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: passCtrl,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              color: AppTheme.textColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(
                color: AppTheme.secondaryText(context),
                fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              ),
              filled: true,
              fillColor: AppTheme.cardColor(context),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmall ? 14 : 16),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: AppTheme.secondaryText(context),
                size: 20,
              ),
              enabledBorder: _border(AppTheme.borderColor(context)),
              focusedBorder: _border(_kGreenBottom, width: 1.5),
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
          SizedBox(height: isSmall ? 20 : 28),

          // Sign in button (blue gradient)
          SizedBox(
            width: double.infinity,
            height: isSmall ? 48 : 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _kBlueGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login, size: 22),
                          const SizedBox(width: 10),
                          Text('Sign In',
                              style: TextStyle(
                                fontSize: AppTheme.fontSize(context, isSmall ? 15 : 17),
                                fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ),
          SizedBox(height: isSmall ? 20 : 28),

          // Footer note (no link, per design).
          Divider(color: AppTheme.dividerColor(context), height: 1),
          SizedBox(height: isSmall ? 14 : 18),
          Center(
            child: Text(
              'Contact your administrator for access',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 13),
                color: AppTheme.secondaryText(context)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = MediaQuery.of(context).size.height < 600;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [_kPageTopDark, _kPageBottomDark]
              : const [_kPageTop, _kPageBottom],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Blue brand header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: isSmall ? 24 : 34),
                        decoration: const BoxDecoration(gradient: _kBlueGradient),
                        child: _BrandHeader(
                          iconSize: isSmall ? 64 : 78,
                          nameSize: AppTheme.fontSize(context, isSmall ? 26 : 30),
                          taglineSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
                        ),
                      ),
                      // White form body
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24, isSmall ? 20 : 28, 24, isSmall ? 20 : 24),
                        child: _buildForm(context),
                      ),
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

  /// Full-screen blue splash with the brand mark and a loading spinner,
  /// shown while the login form "loads".
  Widget _buildSplash(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,              colors: isDark
                  ? const [_kPageTopDark, _kGreenTop]
                  : const [_kPageTop, _kGreenBottom],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: _BrandHeader(
                  iconSize: 92,
                  nameSize: 36,
                  taglineSize: 16,
                ),
              ),
            ),
            // Loading indicator — signals the app is preparing the login form.
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 48),
          ],
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
