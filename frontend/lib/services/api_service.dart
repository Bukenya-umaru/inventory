import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  /// API base URL, normalized to always end with `/api` and have no
  /// trailing slash, so misconfigured values like `https://host/` or
  /// `https://host` still resolve to `https://host/api/...`.
  static String get baseUrl {
    final url = _resolveBaseUrl().trim().replaceAll(RegExp(r'/+$'), '');
    if (url.endsWith('/api')) return url;
    return '$url/api';
  }

  static String _resolveBaseUrl() {
    if (kIsWeb) {
      return _env('API_BASE_URL') ?? 'http://localhost:5000/api';
    }
    if (Platform.isAndroid) {
      return _env('API_BASE_URL_ANDROID') ??
          _env('API_BASE_URL') ??
          'http://10.0.2.2:5000/api';
    }
    return _env('API_BASE_URL') ?? 'http://localhost:5000/api';
  }

  static String? _env(String key) =>
      dotenv.isInitialized ? dotenv.maybeGet(key) : null;

  static String get serverUrl => baseUrl.replaceAll(RegExp(r'/api/?$'), '');

  static String fileUrl(String? path) =>
      (path == null || path.isEmpty) ? '' : '$serverUrl$path';

  /// Fetches raw bytes of a server-hosted file (e.g. a business logo).
  /// Returns null if the path is empty, the request fails, or the status
  /// is not 200.
  static Future<Uint8List?> fetchFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(fileUrl(path)));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {
      // Ignore network errors; callers fall back to no-file behavior.
    }
    return null;
  }

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

  static Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
  ) async {
    final body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      body['message'] ?? 'Request failed',
      response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        'Cannot connect to server. Make sure the backend is running on port 5000.',
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out. The server may be down or unreachable.',
      );
    } on http.ClientException {
      throw ApiException('Network error. Check your internet connection.');
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/auth/me'), headers: _headers())
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException('Cannot connect to server.');
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    }
  }

  static Future<Map<String, dynamic>> changePassword(
    String current,
    String newPassword,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: _headers(),
      body: json.encode({
        'currentPassword': current,
        'newPassword': newPassword,
      }),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getTenants({
    String? status,
    String? search,
  }) async {
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

  static Future<Map<String, dynamic>> suspendTenant(
    String id,
    String reason,
  ) async {
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

  static Future<Map<String, dynamic>> createTenant(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tenants'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

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
      request.files.add(
        http.MultipartFile.fromBytes(
          'businessLogo',
          logoBytes,
          filename: logoName ?? 'logo.png',
        ),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getTenantDashboard(
    String id, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null) {
      params['startDate'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      params['endDate'] = endDate.toIso8601String();
    }
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tenants/$id/dashboard',
      ).replace(queryParameters: params.isEmpty ? null : params),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateBranding(
    String tenantId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tenants/$tenantId/branding'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateTenant(
    String tenantId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tenants/$tenantId'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateTenantWithLogo(
    String tenantId,
    Map<String, dynamic> data,
    List<int>? logoBytes,
    String? logoName,
  ) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/tenants/$tenantId'),
    );
    request.headers['Authorization'] = '******';
    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });
    if (logoBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'businessLogo',
          logoBytes,
          filename: logoName ?? 'logo.png',
        ),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

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
      request.files.add(
        http.MultipartFile.fromBytes(
          'businessLogo',
          logoBytes,
          filename: logoName ?? 'logo.png',
        ),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getUsers({
    String? role,
    String? search,
  }) async {
    final params = <String, String>{};
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/users').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> suspendUser(
    String userId, {
    String? reason,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/suspend'),
      headers: _headers(),
      body: json.encode({'reason': reason ?? 'Account suspended'}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> reactivateUser(String userId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/reactivate'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updatePermissions(
    String userId,
    List<String> permissions,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/permissions'),
      headers: _headers(),
      body: json.encode({'permissions': permissions}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteUser(
    String userId, {
    String? reason,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers(),
      body: json.encode({'reason': reason ?? 'Deleted'}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getProducts({
    String? search,
    bool? lowStock,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (lowStock == true) params['lowStock'] = 'true';
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, dynamic> data,
  ) async {
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

  // ── Suppliers ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSuppliers({String? search}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse(
      '$baseUrl/suppliers',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createSupplier(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/suppliers'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateSupplier(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/suppliers/$id'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteSupplier(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/suppliers/$id'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getCategories({
    String type = 'product',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/categories',
    ).replace(queryParameters: {'type': type});
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createCategory(
    String name, {
    String? description,
    String type = 'product',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: _headers(),
      body: json.encode({
        'name': name,
        'description': description,
        'type': type,
      }),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateCategory(
    String id,
    String name,
  ) async {
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

  static Future<Map<String, dynamic>> getSales({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty)
      params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/sales').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createSale(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getDamages({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty)
      params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/damages').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createDamage(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/damages'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getPurchases({
    String? startDate,
    String? endDate,
    String? status,
    String? paymentMethod,
    bool? creditPaid,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty)
      params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      params['paymentMethod'] = paymentMethod;
    }
    if (creditPaid != null) params['creditPaid'] = '$creditPaid';
    final uri = Uri.parse(
      '$baseUrl/purchases',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createPurchase(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/purchases'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getExpenses({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty)
      params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse('$baseUrl/expenses').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createExpense(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  /// Edit a still-pending stock record (before owner approval).
  static Future<Map<String, dynamic>> updatePurchase(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/purchases/$id'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  /// Business-owner action: approve a pending stock record, applying its
  /// quantity to the product stock and locking it from further edits.
  static Future<Map<String, dynamic>> approvePurchase(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/purchases/$id/approve'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> approveSale(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales/$id/approve'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> markPurchaseCreditPaid(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/purchases/$id/mark-paid'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getProfitReport({
    String period = 'daily',
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{'period': period};
    if (startDate != null && startDate.isNotEmpty)
      params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse(
      '$baseUrl/reports/profit',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getDetailedReport({
    String period = 'daily',
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{'period': period};
    if (startDate != null && startDate.isNotEmpty)
      params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final uri = Uri.parse(
      '$baseUrl/reports/detailed',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  /// Dashboard summary for any tenant member (admins and employees):
  /// today/monthly totals plus 30-day trend, top products and payments.
  static Future<Map<String, dynamic>> getReportSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/summary'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getInventoryReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/inventory'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> createAdminAccount(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/admin'),
      headers: _headers(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getActivity({
    int limit = 50,
    List<String>? types,
    String? search,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (types != null && types.isNotEmpty) params['types'] = types.join(',');
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
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

  static Future<Map<String, dynamic>> getAuditLogs({
    String? eventType,
    String? severity,
    String? startDate,
    String? endDate,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (eventType != null && eventType.isNotEmpty) {
      params['eventType'] = eventType;
    }
    if (severity != null && severity.isNotEmpty) {
      params['severity'] = severity;
    }
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
    }
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final uri = Uri.parse('$baseUrl/audit').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getBusinessActivityLogs({
    String? eventType,
    String? severity,
    String? startDate,
    String? endDate,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (eventType != null && eventType.isNotEmpty) {
      params['eventType'] = eventType;
    }
    if (severity != null && severity.isNotEmpty) {
      params['severity'] = severity;
    }
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
    }
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final uri = Uri.parse('$baseUrl/audit/business-activity')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> viewPassword(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/passwords/view/$userId'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> resetPassword(
    String userId,
    String newPassword,
  ) async {
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
