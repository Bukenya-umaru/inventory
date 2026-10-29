import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/app_drawer.dart' show ThemeToggleFab;
import '../../utils/theme.dart';

/// Duration the blue splash is shown before revealing the login page.
const Duration _kSplashDuration = Duration(seconds: 2);

const Color _kStoreGreen = Color(0xFF155D2B);
const Color _kFieldGreen = Color(0xFF4D9E5A);
const Color _kPageCream = Color(0xFFFFF8D8);

/// Store House mark shown while the login screen is loading.
class _BrandHeader extends StatelessWidget {
  final double iconSize;
  final double nameSize;

  const _BrandHeader({required this.iconSize, required this.nameSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            Icons.warehouse_outlined,
            size: iconSize * 0.58,
            color: Colors.white,
          ),
        ),
        SizedBox(height: iconSize * 0.22),
        Text(
          'Store House',
          style: TextStyle(
            color: Colors.white,
            fontSize: nameSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

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

  Widget _buildForm(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.height < 600;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Store House',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, isSmall ? 24 : 28),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: isSmall ? 8 : 12),
                Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, isSmall ? 19 : 22),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmall ? 22 : 32),

          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFFD2C9),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.fontSize(context, 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              ),
              filled: true,
              fillColor: _kFieldGreen,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isSmall ? 13 : 16,
              ),
              suffixIcon: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFFFD2C9)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: Color(0xFFFFD2C9),
                  width: 1.5,
                ),
              ),
            ),
            textAlignVertical: TextAlignVertical.center,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          SizedBox(height: isSmall ? 16 : 22),

          TextFormField(
            controller: passCtrl,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
              ),
              filled: true,
              fillColor: _kFieldGreen,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isSmall ? 13 : 16,
              ),
              suffixIconColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFFFD2C9)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: Color(0xFFFFD2C9),
                  width: 1.5,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            textAlignVertical: TextAlignVertical.center,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
          SizedBox(height: isSmall ? 20 : 28),

          SizedBox(
            width: double.infinity,
            height: isSmall ? 48 : 52,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                disabledBackgroundColor: Colors.white70,
                foregroundColor: _kStoreGreen,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: _kStoreGreen,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Login',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 15 : 17),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.height < 600;

    final verticalPadding = isSmall ? 20.0 : 24.0;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Stretch the scrollable area to at least the viewport height so
                // the card sits in the middle of the screen instead of at the
                // top, while still scrolling if it does not fit.
                final minHeight = constraints.maxHeight - verticalPadding * 2;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 18 : 24,
                    vertical: verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minHeight > 0 ? minHeight : 0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 470),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _kStoreGreen,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF102716,
                                ).withValues(alpha: 0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 24 : 46,
                            vertical: isSmall ? 28 : 40,
                          ),
                          child: _buildForm(context),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Contact your administrator for access',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 13),
                color: _kStoreGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(_kPageCream, BlendMode.src);
    final wallPaint = Paint()..color = const Color(0xFFEEDDA8);
    final shelfPaint = Paint()
      ..color = const Color(0xFFD8A765)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final boxPaint = Paint()..color = const Color(0xFFDFA66B);
    final boxLightPaint = Paint()..color = const Color(0xFFF1BF7C);
    final boxLinePaint = Paint()
      ..color = const Color(0xFFB97942)
      ..strokeWidth = 2;

    final wallHeight = size.height * 0.72;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, wallHeight), wallPaint);

    final beamPaint = Paint()
      ..color = const Color(0xFFE4CB8E)
      ..strokeWidth = 3;
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.12 + i * 0.085);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), beamPaint);
    }

    void drawShelf(double left, double top, double width) {
      canvas.drawLine(Offset(left, top), Offset(left + width, top), shelfPaint);
      canvas.drawLine(
        Offset(left, top + 78),
        Offset(left + width, top + 78),
        shelfPaint,
      );
      canvas.drawLine(
        Offset(left + 5, top - 4),
        Offset(left + 5, top + 85),
        shelfPaint,
      );
      canvas.drawLine(
        Offset(left + width - 5, top - 4),
        Offset(left + width - 5, top + 85),
        shelfPaint,
      );
      final crateWidth = width * 0.36;
      for (var i = 0; i < 2; i++) {
        final x = left + 14 + i * (crateWidth + 12);
        final rect = Rect.fromLTWH(x, top - 48, crateWidth, 43);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          boxPaint,
        );
        canvas.drawLine(
          Offset(x + crateWidth * 0.5, top - 46),
          Offset(x + crateWidth * 0.5, top - 7),
          boxLinePaint,
        );
      }
      final lower = Rect.fromLTWH(left + 18, top + 31, width * 0.48, 42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lower, const Radius.circular(3)),
        boxLightPaint,
      );
      canvas.drawLine(
        Offset(lower.left + lower.width * 0.5, lower.top + 2),
        Offset(lower.left + lower.width * 0.5, lower.bottom - 2),
        boxLinePaint,
      );
    }

    final shelfTop = size.height * 0.59;
    drawShelf(-size.width * 0.12, shelfTop, size.width * 0.4);
    drawShelf(size.width * 0.72, shelfTop, size.width * 0.4);

    final hill = Path()
      ..moveTo(0, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.66,
        size.width * 0.43,
        size.height * 0.75,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.84,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF0B6A2D));
  }

  @override
  bool shouldRepaint(covariant _WarehouseBackgroundPainter oldDelegate) =>
      false;
}

class StoreHouseSplash extends StatefulWidget {
  const StoreHouseSplash({super.key});

  @override
  State<StoreHouseSplash> createState() => _StoreHouseSplashState();
}

class _StoreHouseSplashState extends State<StoreHouseSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(_pulse);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _WarehouseBackgroundPainter()),
        SafeArea(
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: Tween<double>(begin: 0.6, end: 1).animate(_pulse),
                child: ScaleTransition(
                  scale: _scale,
                  child: const _BrandHeader(iconSize: 76, nameSize: 32),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: _kStoreGreen,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading your workspace...',
                style: TextStyle(
                  color: _kStoreGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTheme.fontSize(context, 14),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
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
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final error = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = AppTheme.isPhoneScreen(context);
    return Scaffold(
      floatingActionButton: isPhone && _showSplash
          ? null
          : const ThemeToggleFab(),
      backgroundColor: _kPageCream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isPhone && _showSplash)
            const StoreHouseSplash()
          else ...[
            CustomPaint(painter: _WarehouseBackgroundPainter()),
            _LoginFormView(
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              passCtrl: _passCtrl,
              loading: _loading,
              obscure: _obscure,
              error: _error,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSubmit: _login,
            ),
          ],
        ],
      ),
    );
  }
}
