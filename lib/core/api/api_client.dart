import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _authTokenKey = 'medguard_auth_token';
  static const String _userDataKey = 'medguard_user_data';

  String? _cachedToken;

  /// Determine the appropriate Base URL according to target platform
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5001/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5001/api';
    } else {
      return 'http://localhost:5001/api';
    }
  }

  /// Get stored JWT token
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_authTokenKey);
    return _cachedToken;
  }

  /// Store JWT token and User data locally
  Future<void> saveAuthSession(String token, Map<String, dynamic> userMap) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
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
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET Request
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// POST Request
  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http
        .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// PUT Request
  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http
        .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// PATCH Request
  Future<Map<String, dynamic>> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http
        .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// DELETE Request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// Upload File Request (Multipart)
  Future<Map<String, dynamic>> uploadFile(
    String endpoint, {
    required String filePath,
    required String fileFieldName,
    Map<String, String>? fields,
    Uint8List? bytes,
    String? filename,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final token = await getToken();

    final request = http.MultipartRequest('POST', uri);
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

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
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
    } else {
      final message = (decoded is Map && decoded.containsKey('message'))
          ? decoded['message']
          : 'HTTP ${response.statusCode}: Request failed';
      throw Exception(message);
    }
  }
}
