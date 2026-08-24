import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand colors (used in both themes) ──
  static const Color primary = Color(0xFFE53935);
  static const Color primaryDark = Color(0xFFC62828);
  static const Color sidebarBg = Color(0xFF2D2D2D);
  static const Color sidebarActive = Color(0xFFE53935);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  // ── Light-theme colors ──
  static const Color surface = Color(0xFFF5F5F5);
  static const Color card = Colors.white;
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF757575);

  // ── Dark-theme colors ──
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);

  // ── Theme-aware helpers ──
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Primary text color — adapts to light/dark theme.
  static Color textColor(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : textPrimary;

  /// Secondary / muted text color — adapts to light/dark theme.
  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : textSecondary;

  /// Surface / scaffold background — adapts to light/dark theme.
  static Color surfaceColor(BuildContext context) =>
      _isDark(context) ? darkSurface : surface;

  /// Card background — adapts to light/dark theme.
  static Color cardColor(BuildContext context) =>
      _isDark(context) ? darkCard : card;

  /// AppBar background — adapts to light/dark theme.
  static Color appBarColor(BuildContext context) =>
      _isDark(context) ? darkSurface : Colors.white;

  /// Password-reveal container background when revealed.
  static Color passwordRevealedBg(BuildContext context) =>
      _isDark(context) ? success.withValues(alpha: 0.15) : const Color(0xFFE8F5E9);

  /// Password-reveal container background when hidden.
  static Color passwordHiddenBg(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : Colors.grey.shade100;

  /// Subtle muted text for icons/labels.
  static Color mutedIcon(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade400 : Colors.grey;

  /// Brighter version of primary for dark backgrounds.
  static Color primaryBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEF5350) : primary;

  /// Brighter version of success for dark backgrounds.
  static Color successBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFF4CAF50) : success;

  /// Brighter version of warning for dark backgrounds.
  static Color warningBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFB74D) : warning;

  /// Brighter version of danger for dark backgrounds.
  static Color dangerBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEF5350) : danger;

  /// Brighter blue for dark backgrounds.
  static Color blueBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFF42A5F5) : const Color(0xFF1565C0);

  // ── Responsive text sizing ──
  static double fontSize(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return base * 1.35;
    if (w >= 900) return base * 1.2;
    return base;
  }

  static double pad(BuildContext context, double base) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return base * 1.3;
    if (w >= 900) return base * 1.15;
    return base;
  }

  // ── Light theme ──
  static ThemeData get theme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.red,
    primaryColor: primary,
    scaffoldBackgroundColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );

  // ── Dark theme ──
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.red,
    primaryColor: primary,
    scaffoldBackgroundColor: darkSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
