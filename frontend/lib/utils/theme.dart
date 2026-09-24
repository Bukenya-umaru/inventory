import 'package:flutter/material.dart';

class AppTheme {

  // Splash / login accent (blue).
  static const Color splashBlue = Color(0xFF1565C0);
  static const Color splashBlueDark = Color(0xFF0D47A1);

  static const Color primary = Color(0xFFE53935);
  static const Color primaryDark = Color(0xFFC62828);

  // Dashboard design language: white rounded cards on a light gray canvas,
  // pill accents and outlined status chips (see dashboard mock).
  static const Color canvas = Color(0xFFEFF2F6);
  static const Color panelBg = Color(0xFFF1F4F8);
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color sidebarActive = Color(0xFF123F57);
  static const Color dashNavy = Color(0xFF123F57);
  static const Color dashOrange = Color(0xFFF97316);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  static const Color surface = Color(0xFFF5F5F5);
  static const Color card = Colors.white;
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF757575);

  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);

  // Dark-mode counterparts for the light design-system constants.
  static const Color darkCanvas = Color(0xFF0D0D0D);
  static const Color darkPanelBg = Color(0xFF181818);
  static const Color darkSidebarBg = Color(0xFF161616);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// True on phone-sized screens (including phones held sideways), false on
  /// tablets, laptops and desktops. Used to gate mobile-only affordances such
  /// as the download-app button.
  static bool isPhoneScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide < 600;
  }

  static Color textColor(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : textPrimary;

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : textSecondary;

  static Color surfaceColor(BuildContext context) =>
      _isDark(context) ? darkSurface : surface;

  static Color cardColor(BuildContext context) =>
      _isDark(context) ? darkCard : card;

  static Color panelColor(BuildContext context) =>
      _isDark(context) ? darkPanelBg : panelBg;

  static Color canvasColor(BuildContext context) =>
      _isDark(context) ? darkCanvas : canvas;

  static Color sidebarColor(BuildContext context) =>
      _isDark(context) ? darkSidebarBg : sidebarBg;

  static Color dashNavyColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFF7EB6D9) : dashNavy;

  static Color dividerColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : Colors.grey.shade200;

  static Color borderColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : Colors.grey.shade300;

  static Color appBarColor(BuildContext context) =>
      _isDark(context) ? darkSurface : Colors.white;

  static Color passwordRevealedBg(BuildContext context) =>
      _isDark(context) ? success.withValues(alpha: 0.15) : const Color(0xFFE8F5E9);

  static Color passwordHiddenBg(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : Colors.grey.shade100;

  static Color mutedIcon(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade400 : Colors.grey;

  static Color primaryBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEF5350) : primary;

  static Color successBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFF4CAF50) : success;

  static Color warningBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFB74D) : warning;

  static Color dangerBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEF5350) : danger;

  static Color blueBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFF42A5F5) : const Color(0xFF1565C0);

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

  static const double dialogMaxWidth = 480;

  static ThemeData get theme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.red,
    primaryColor: primary,
    scaffoldBackgroundColor: surface,
    dividerColor: Colors.grey.shade200,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dialogTheme: const DialogThemeData(
      constraints: BoxConstraints(maxWidth: dialogMaxWidth),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.red,
    primaryColor: primary,
    scaffoldBackgroundColor: darkSurface,
    dividerColor: Colors.grey.shade800,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dialogTheme: const DialogThemeData(
      constraints: BoxConstraints(maxWidth: dialogMaxWidth),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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