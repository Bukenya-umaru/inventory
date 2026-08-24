import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'dark_mode';
  bool _isDark = false;
  SharedPreferences? _prefs;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    _isDark = _prefs!.getBool(_key) ?? false;
    notifyListeners();
  }

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
    // Persist in background — don't await, so the UI updates instantly
    _prefs?.setBool(_key, _isDark);
  }
}
