import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Auto-detect: emulator uses 10.0.2.2, real device uses localhost
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (Platform.isAndroid) {
      // Works for both emulator and real device on local network
      return 'http://10.0.2.2:5000/api';
    }
    // iOS, desktop, etc.
    return 'http://localhost:5000/api';
  }

  /// Server root (no /api suffix) — used for uploaded files like logos.
  static String get serverUrl => baseUrl.replaceAll(RegExp(r'/api/?$'), '');

  /// Full URL for an uploaded file path (e.g. '/uploads/logos/123.png').
  static String fileUrl(String? path) =>
      (path == null || path.isEmpty) ? '' : '$serverUrl$path';

  static String? _token;

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(body['message'] ?? 'Request failed', response.statusCode);
  }

  // ── Auth ──
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException('Cannot connect to server. Make sure the backend is running on port 5000.');
    } on TimeoutException {
      throw ApiException('Connection timed out. The server may be down or unreachable.');
    } on http.ClientException {
      throw ApiException('Network error. Check your internet connection.');
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException('Cannot connect to server.');
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    }
  }

  static Future<Map<String, dynamic>> changePassword(String current, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: _headers(),
      body: json.encode({'currentPassword': current, 'newPassword': newPassword}),
    );
    return _handleResponse(response);
  }

  // ── Tenants ──
  static Future<Map<String, dynamic>> getTenants({String? status, String? search}) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/tenants').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getTenantStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tenants/stats'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> suspendTenant(String id, String reason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tenants/$id/suspend'),
      headers: _headers(),
      body: json.encode({'reason': reason}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> reactivateTenant(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tenants/$id/reactivate'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteTenant(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/tenants/$id'),
      headers: _headers(),
      body: json.encode({'confirmation': 'DELETE'}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createTenant(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tenants'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  /// Create tenant with optional logo bytes (multipart upload, web-compatible)
  static Future<Map<String, dynamic>> createTenantWithLogo(
    Map<String, dynamic> data,
    List<int>? logoBytes,
    String? logoName,
  ) async {
    final uri = Uri.parse('$baseUrl/tenants');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $_token';
    data.forEach((key, value) {
      if (value is List) {
        for (var item in value) {
          request.fields['$key'] = item.toString();
        }
      } else {
        request.fields[key] = value?.toString() ?? '';
      }
    });
    if (logoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'businessLogo',
        logoBytes,
        filename: logoName ?? 'logo.png',
      ));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getTenantDashboard(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tenants/$id/dashboard'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateBranding(String tenantId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tenants/$tenantId/branding'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  /// Update branding with optional logo bytes (multipart upload, web-compatible)
  static Future<Map<String, dynamic>> updateBrandingWithLogo(
    String tenantId,
    Map<String, dynamic> data,
    List<int>? logoBytes,
    String? logoName,
  ) async {
    final uri = Uri.parse('$baseUrl/tenants/$tenantId/branding');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $_token';
    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });
    if (logoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'businessLogo',
        logoBytes,
        filename: logoName ?? 'logo.png',
      ));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  // ── Users ──
  static Future<Map<String, dynamic>> getUsers({String? role, String? search}) async {
    final params = <String, String>{};
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/users').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updatePermissions(String userId, List<String> permissions) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/permissions'),
      headers: _headers(),
      body: json.encode({'permissions': permissions}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteUser(String userId, {String? reason}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers(),
      body: json.encode({'reason': reason ?? 'Deleted'}),
    );
    return _handleResponse(response);
  }

  // ── Products ──
  static Future<Map<String, dynamic>> getProducts({String? search, bool? lowStock}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (lowStock == true) params['lowStock'] = 'true';
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteProduct(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/products/$id'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  // ── Categories ──
  static Future<Map<String, dynamic>> getCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createCategory(String name, {String? description}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: _headers(),
      body: json.encode({'name': name, 'description': description}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateCategory(String id, String name) async {
    final response = await http.put(
      Uri.parse('$baseUrl/categories/$id'),
      headers: _headers(),
      body: json.encode({'name': name}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteCategory(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/categories/$id'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  // ── Sales ──
  static Future<Map<String, dynamic>> getSales({String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/sales').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  // ── Damages ──
  static Future<Map<String, dynamic>> getDamages({String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/damages').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createDamage(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/damages'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  // ── Purchases (Add Stock) ──
  static Future<Map<String, dynamic>> getPurchases({String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/purchases').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/purchases'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  // ── Reports ──
  static Future<Map<String, dynamic>> getProfitReport({String period = 'daily', String? startDate, String? endDate}) async {
    final params = <String, String>{'period': period};
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/reports/profit').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getDetailedReport({String period = 'daily', String? startDate, String? endDate}) async {
    final params = <String, String>{'period': period};
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/reports/detailed').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getInventoryReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/inventory'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  // ── Developer: Create Admin Account ──
  static Future<Map<String, dynamic>> createAdminAccount(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/admin'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  // ── Activity notifications ──
  static Future<Map<String, dynamic>> getActivity({int limit = 50, List<String>? types}) async {
    final params = <String, String>{'limit': '$limit'};
    if (types != null && types.isNotEmpty) params['types'] = types.join(',');
    final response = await http.get(
      Uri.parse('$baseUrl/audit/activity').replace(queryParameters: params),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<void> markActivitiesSeen() async {
    final response = await http.post(
      Uri.parse('$baseUrl/audit/activity/seen'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  // ── Audit ──
  static Future<Map<String, dynamic>> getAuditLogs({String? eventType, String? severity}) async {
    final params = <String, String>{};
    if (eventType != null && eventType.isNotEmpty) params['eventType'] = eventType;
    if (severity != null && severity.isNotEmpty) params['severity'] = severity;
    final uri = Uri.parse('$baseUrl/audit').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  // ── Passwords ──
  static Future<Map<String, dynamic>> viewPassword(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/passwords/view/$userId'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> resetPassword(String userId, String newPassword) async {
    final response = await http.put(
      Uri.parse('$baseUrl/passwords/reset/$userId'),
      headers: _headers(),
      body: json.encode({'newPassword': newPassword}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getPasswordAuditLogs() async {
    final response = await http.get(
      Uri.parse('$baseUrl/passwords/audit'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
