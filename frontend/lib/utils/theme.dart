import 'package:flutter/material.dart';

class AppTheme {

  // Brand green (primary actions, active nav, success) — Inviro look.
  static const Color primary = Color(0xFF1DBF73);
  static const Color primaryDark = Color(0xFF14995B);
  // Inviro secondary accents.
  static const Color teal = Color(0xFF1DBF73);
  // Blue accent (links, references).
  static const Color linkBlue = Color(0xFF4C8DDB);

  // Splash / login accent (green family).
  static const Color splashBlue = Color(0xFF1DBF73);
  static const Color splashBlueDark = Color(0xFF14995B);

  // Dark-mode tokens (charcoal counterparts; light Inviro look is default).
  static const Color darkCanvas = Color(0xFF16191D);
  static const Color darkSurface = Color(0xFF16191D);
  static const Color darkCard = Color(0xFF1E2429);
  static const Color darkPanelBg = Color(0xFF1E2429);
  static const Color darkSidebarBg = Color(0xFF111417);
  static const Color darkTextPrimary = Color(0xFFE8EEF2);
  static const Color darkTextSecondary = Color(0xFF8CA0AB);

  // Light-mode tokens — the Inviro look (default): white surfaces,
  // light gray-blue canvas, green brand accent.
  static const Color canvas = Color(0xFFF3F5F7);
  static const Color panelBg = Color(0xFFF6F8FA);
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color sidebarActive = Color(0xFF1DBF73);
  static const Color dashNavy = Color(0xFF14995B);
  static const Color dashOrange = Color(0xFFFDA23B);
  static const Color success = Color(0xFF1DBF73);
  static const Color warning = Color(0xFFFDA23B);
  static const Color danger = Color(0xFFE03B30);

  static const Color surface = Color(0xFFF3F5F7);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF232A2F);
  static const Color textSecondary = Color(0xFF6B7A83);

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
      _isDark(context) ? const Color(0xFF2BD98A) : dashNavy;

  static Color dividerColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFF263238) : Colors.grey.shade200;

  static Color borderColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2C3A42) : Colors.grey.shade300;

  static Color appBarColor(BuildContext context) =>
      _isDark(context) ? darkSurface : Colors.white;

  static Color passwordRevealedBg(BuildContext context) =>
      _isDark(context) ? primary.withValues(alpha: 0.15) : const Color(0xFFE8F5E9);

  static Color passwordHiddenBg(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : Colors.grey.shade100;

  static Color mutedIcon(BuildContext context) =>
      _isDark(context) ? const Color(0xFF7A8C96) : Colors.grey;

  static Color primaryBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2BD98A) : primary;

  static Color successBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2BD98A) : success;

  static Color warningBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFDB55F) : warning;

  static Color dangerBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFF6B61) : danger;

  static Color blueBright(BuildContext context) =>
      _isDark(context) ? const Color(0xFF6FA9E8) : linkBlue;

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
    primarySwatch: Colors.green,
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
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    primaryColor: primary,
    scaffoldBackgroundColor: darkSurface,
    dividerColor: const Color(0xFF263238),
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
        side: BorderSide(color: const Color(0xFF263238)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2C3A42)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2C3A42)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: const Color(0xFF0C1112),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}