import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/branding.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Branding? _branding;
  bool _loading = true;

  User? get user => _user;
  Branding? get branding => _branding;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;

  Future<void> init() async {
    try {
      final token = await ApiService.getToken();
      if (token != null) {
        final res = await ApiService.getMe();
        _user = User.fromJson(res['user']);
        if (res['branding'] != null) {
          _branding = Branding.fromJson(res['branding']);
        }
      }
    } catch (e) {

      await ApiService.clearToken();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshBranding() async {
    if (_user == null) return;
    try {
      final res = await ApiService.getMe();
      _user = User.fromJson(res['user']);
      _branding = res['branding'] != null ? Branding.fromJson(res['branding']) : null;
      notifyListeners();
    } catch (_) {

    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final res = await ApiService.login(email, password);
      await ApiService.setToken(res['token']);
      _user = User.fromJson(res['user']);
      if (res['branding'] != null) {
        _branding = Branding.fromJson(res['branding']);
      }
      notifyListeners();
      return null; 
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: ${e.runtimeType}. Please check that the backend server is running on port 5000.';
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    _branding = null;
    notifyListeners();
  }
}