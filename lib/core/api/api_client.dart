import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../errors/app_exception.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _authTokenKey = 'medguard_auth_token';
  static const String _userDataKey = 'medguard_user_data';

  String? _cachedToken;

  String? _customBaseUrl;

  /// Allows setting a custom backend URL (e.g. for physical Android test over LAN)
  void setCustomBaseUrl(String? url) {
    _customBaseUrl = url;
  }

  /// Determine the appropriate Base URL (defaults to Render production cloud backend)
  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      final trimmed = _customBaseUrl!.trim().replaceFirst(RegExp(r'/+$'), '');
      return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
    }
    return ApiConfig.apiUrl;
  }

  /// Inspect JWT token expiration timestamp
  bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map.containsKey('exp')) {
        final expSec = map['exp'] as int;
        final expiry = DateTime.fromMillisecondsSinceEpoch(expSec * 1000);
        return DateTime.now().isAfter(expiry);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get stored JWT token
  Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.trim().isNotEmpty) {
      if (isTokenExpired(_cachedToken!)) {
        await clearAuthSession();
        return null;
      }
      return _cachedToken;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_authTokenKey);
    if (stored != null && stored.trim().isNotEmpty) {
      if (isTokenExpired(stored)) {
        await clearAuthSession();
        return null;
      }
      _cachedToken = stored.trim();
      return _cachedToken;
    }
    return null;
  }

  /// Store JWT token and User data locally
  Future<void> saveAuthSession(String token, Map<String, dynamic> userMap) async {
    final cleanToken = token.trim();
    _cachedToken = cleanToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, cleanToken);
    await prefs.setString(_userDataKey, jsonEncode(userMap));
  }

  /// Clear session on logout
  Future<void> clearAuthSession() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userDataKey);
  }

  /// Get stored user map
  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userDataKey);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final token = await getToken();
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET Request with bounded transient retry
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    http.Response response;
    try {
      response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    }

    return _handleResponse(response);
  }

  /// POST Request with bounded transient retry
  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    http.Response response;
    try {
      response = await http
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    }

    return _handleResponse(response);
  }

  /// PUT Request with bounded transient retry
  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    http.Response response;
    try {
      response = await http
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    }

    return _handleResponse(response);
  }

  /// PATCH Request with bounded transient retry
  Future<Map<String, dynamic>> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    http.Response response;
    try {
      response = await http
          .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http
          .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http
          .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
    }

    return _handleResponse(response);
  }

  /// DELETE Request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  /// Download binary bytes with JWT Authorization header
  Future<Uint8List> downloadBytes(String endpoint) async {
    final uri = endpoint.startsWith('http://') || endpoint.startsWith('https://')
        ? Uri.parse(endpoint)
        : Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 45));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else if (response.statusCode == 401) {
      _cachedToken = null;
      throw AuthenticationException('Authentication required to access document.');
    } else {
      throw Exception('Failed to download document (HTTP ${response.statusCode})');
    }
  }

  /// Upload File Request (Multipart)
  Future<Map<String, dynamic>> uploadFile(
    String endpoint, {
    required String filePath,
    required String fileFieldName,
    Map<String, String>? fields,
    Uint8List? bytes,
    String? filename,
    String method = 'POST',
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final token = await getToken();

    final request = http.MultipartRequest(method, uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    if (bytes != null && filename != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileFieldName,
        bytes,
        filename: filename,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(fileFieldName, filePath));
    }

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'success': true, 'data': decoded};
    } else if (response.statusCode == 401) {
      _cachedToken = null;
      final message = (decoded is Map && decoded.containsKey('message'))
          ? decoded['message']
          : 'Authentication required. No token provided.';
      throw AuthenticationException(message.toString());
    } else if (response.statusCode == 503) {
      final msg = (decoded is Map && decoded.containsKey('message'))
          ? decoded['message'].toString()
          : 'Server is connecting to MongoDB Atlas. Please tap retry in a few seconds.';
      throw ServerUnavailableException(msg);
    } else {
      final message = (decoded is Map && decoded.containsKey('message'))
          ? decoded['message']
          : 'HTTP ${response.statusCode}: Request failed';
      throw Exception(message);
    }
  }
}
