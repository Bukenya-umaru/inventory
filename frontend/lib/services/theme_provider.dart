import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _keyDark = 'dark_mode';
  static const _keyAccent = 'accent_color';
  bool _isDark = false;
  int _accentColorValue = 0xFFE53935; // default red
  SharedPreferences? _prefs;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;
  Color get accentColor {
    final v = _accentColorValue;
    return Color.fromARGB(
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    );
  }

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    _isDark = _prefs!.getBool(_keyDark) ?? false;
    _accentColorValue = _prefs!.getInt(_keyAccent) ?? 0xFFE53935;
    notifyListeners();
  }

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
    _prefs?.setBool(_keyDark, _isDark);
  }

  void setAccentColor(Color color) {
    final v = color.value;
    _accentColorValue = v;
    notifyListeners();
    _prefs?.setInt(_keyAccent, v);
  }
}
