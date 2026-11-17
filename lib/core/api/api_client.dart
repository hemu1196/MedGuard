import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../../services/private_local_store.dart';
import '../../services/health_preferences.dart';
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

  @visibleForTesting
  void resetForTesting() {
    _sessionGeneration++;
    _cachedToken = null;
    _sessionTail = null;
    _customBaseUrl = null;
  }

  int _sessionGeneration = 0;
  Future<void>? _sessionTail;
  static const _cacheOwnerKey = 'medguard_cache_owner';
  Future<T> _sessionOperation<T>(Future<T> Function() task) {
    final result = (_sessionTail ?? Future<void>.value()).then((_) => task());
    _sessionTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// A local shape/expiry check only; the server verifies signatures and sessions.
  bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3 || parts.any((part) => part.isEmpty)) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      return exp is! int || DateTime.now().millisecondsSinceEpoch >= exp * 1000;
    } catch (_) {
      return true;
    }
  }

  Future<String?> getToken() async {
    final generation = _sessionGeneration;
    final token = await _sessionOperation(() async {
      if (generation != _sessionGeneration) return null;
      final prefs = await SharedPreferences.getInstance();
      final stored =
          _cachedToken ??
          await PrivateLocalStore.read(_authTokenKey) ??
          prefs.getString(_authTokenKey);
      if (stored != null) await PrivateLocalStore.write(_authTokenKey, stored);
      await prefs.remove(_authTokenKey);
      if (generation != _sessionGeneration) return null;
      _cachedToken = stored?.trim();
      return _cachedToken;
    });
    if (token == null || token.isEmpty) return null;
    if (isTokenExpired(token)) {
      await invalidateSession(
        rejectedToken: token,
        requestGeneration: generation,
      );
      return null;
    }
    return token;
  }

  Future<Map<String, dynamic>?> _readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        await PrivateLocalStore.read(_userDataKey) ??
        prefs.getString(_userDataKey);
    if (raw == null) return null;
    try {
      final user = Map<String, dynamic>.from(jsonDecode(raw));
      await PrivateLocalStore.write(_userDataKey, jsonEncode(user));
      await prefs.remove(_userDataKey);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAuthSession(String token, Map<String, dynamic> userMap) {
    final generation = ++_sessionGeneration;
    return _sessionOperation(() async {
      if (generation != _sessionGeneration) return;
      final userId = (userMap['_id'] ?? userMap['id'])?.toString();
      if (userId == null || userId.isEmpty || isTokenExpired(token)) {
        throw AuthenticationException(
          'The server returned an invalid or expired session. Please sign in again.',
        );
      }
      final old = await _readUser();
      final owner =
          await PrivateLocalStore.read(_cacheOwnerKey) ??
          old?['_id']?.toString();
      if (owner != null && owner != userId) {
        await PrivateLocalStore.clear();
        final legacy = await SharedPreferences.getInstance();
        for (final key
            in legacy.getKeys().where(HealthPreferences.isHealthKey).toList()) {
          await legacy.remove(key);
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await PrivateLocalStore.write(_authTokenKey, token.trim());
      await PrivateLocalStore.write(_userDataKey, jsonEncode(userMap));
      await PrivateLocalStore.write(_cacheOwnerKey, userId);
      await prefs.remove(_authTokenKey);
      await prefs.remove(_userDataKey);
      if (generation == _sessionGeneration) _cachedToken = token.trim();
    });
  }

  /// Rejected credentials are removed, while a protected, account-bound draft
  /// survives same-account reauthentication. Intentional logout clears everything.
  Future<void> invalidateSession({
    required String rejectedToken,
    required int requestGeneration,
  }) => _sessionOperation(() async {
    if (requestGeneration != _sessionGeneration) return;
    final current = _cachedToken ?? await PrivateLocalStore.read(_authTokenKey);
    if (current != rejectedToken) return;
    ++_sessionGeneration;
    _cachedToken = null;
    final user = await _readUser();
    if (user?['_id'] != null) {
      await PrivateLocalStore.write(_cacheOwnerKey, user!['_id'].toString());
    }
    await PrivateLocalStore.remove(_authTokenKey);
    await PrivateLocalStore.remove(_userDataKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove('auth_user_id');
    await prefs.setBool('auth_user_session', false);
  });

  Future<void> clearAuthSession() {
    ++_sessionGeneration;
    _cachedToken = null;
    return _sessionOperation(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_userDataKey);
      await prefs.remove('auth_user_id');
      await prefs.setBool('auth_user_session', false);
      await PrivateLocalStore.clear();
      await prefs.setBool('legacy_cache_import_disabled', true);
      for (final key in prefs.getKeys().toList()) {
        if (HealthPreferences.isHealthKey(key)) await prefs.remove(key);
      }
    });
  }

  Future<Map<String, dynamic>?> getStoredUser() {
    final generation = _sessionGeneration;
    return _sessionOperation(() async {
      if (generation != _sessionGeneration) return null;
      final user = await _readUser();
      return generation == _sessionGeneration ? user : null;
    });
  }

  Future<Map<String, String>> _getHeaders({
    bool isJson = true,
    bool includeAuth = true,
    String? expectedUserId,
  }) async {
    final token = includeAuth ? await getToken() : null;
    if (expectedUserId != null) {
      final user = await getStoredUser();
      if (token == null ||
          (user?['_id'] ?? user?['id'])?.toString() != expectedUserId) {
        throw AuthenticationException(
          'Session changed. Sign in to the same account before saving this draft.',
        );
      }
    }
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
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    String? expectedUserId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);
    final headers = await _getHeaders(expectedUserId: expectedUserId);
    final requestGeneration = _sessionGeneration;
    http.Response response;
    try {
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
    }

    return _handleResponse(
      response,
      requestToken: headers['Authorization']?.substring(7),
      requestGeneration: requestGeneration,
    );
  }

  /// POST Request with bounded transient retry
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(
      includeAuth: !const {
        '/auth/login',
        '/auth/register',
        '/auth/firebase-migrate',
        '/auth/request-password-reset',
        '/auth/reset-password',
      }.contains(endpoint),
    );
    final requestGeneration = _sessionGeneration;
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    }

    return _handleResponse(
      response,
      requestToken: headers['Authorization']?.substring(7),
      requestGeneration: requestGeneration,
    );
  }

  /// PUT Request with bounded transient retry
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? expectedUserId,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(expectedUserId: expectedUserId);
    final requestGeneration = _sessionGeneration;
    http.Response response;
    try {
      response = await http
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    }

    return _handleResponse(
      response,
      requestToken: headers['Authorization']?.substring(7),
      requestGeneration: requestGeneration,
    );
  }

  /// PATCH Request with bounded transient retry
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? expectedUserId,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(expectedUserId: expectedUserId);
    final requestGeneration = _sessionGeneration;
    http.Response response;
    try {
      response = await http
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 503) {
      await Future.delayed(const Duration(milliseconds: 2000));
      response = await http
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
    }

    return _handleResponse(
      response,
      requestToken: headers['Authorization']?.substring(7),
      requestGeneration: requestGeneration,
    );
  }

  /// DELETE Request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final requestGeneration = _sessionGeneration;
    final response = await http
        .delete(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
    return _handleResponse(
      response,
      requestToken: headers['Authorization']?.substring(7),
      requestGeneration: requestGeneration,
    );
  }

  /// Download binary bytes with JWT Authorization header
  Future<Uint8List> downloadBytes(String endpoint) async {
    final uri =
        endpoint.startsWith('http://') || endpoint.startsWith('https://')
        ? Uri.parse(endpoint)
        : Uri.parse('$baseUrl$endpoint');
    if (uri.origin != Uri.parse(baseUrl).origin) {
      throw Exception('Untrusted document host.');
    }
    final headers = await _getHeaders();
    final requestGeneration = _sessionGeneration;
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 45));
    if (requestGeneration != _sessionGeneration) {
      throw AuthenticationException('Session changed. Please retry.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else if (response.statusCode == 401) {
      final token = headers['Authorization']?.substring(7);
      if (token != null) {
        await invalidateSession(
          rejectedToken: token,
          requestGeneration: requestGeneration,
        );
      }
      throw AuthenticationException(
        'Authentication required to access document.',
      );
    } else {
      throw Exception(
        'Failed to download document (HTTP ${response.statusCode})',
      );
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
    final requestGeneration = _sessionGeneration;

    final request = http.MultipartRequest(method, uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    if (bytes != null && filename != null) {
      MediaType? contentType;
      final ext = filename.split('.').last.toLowerCase();
      if (ext == 'pdf' ||
          (bytes.length >= 4 &&
              bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46)) {
        contentType = MediaType('application', 'pdf');
      } else if (ext == 'png' ||
          (bytes.length >= 8 &&
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47)) {
        contentType = MediaType('image', 'png');
      } else if (ext == 'jpg' ||
          ext == 'jpeg' ||
          (bytes.length >= 3 &&
              bytes[0] == 0xFF &&
              bytes[1] == 0xD8 &&
              bytes[2] == 0xFF)) {
        contentType = MediaType('image', 'jpeg');
      } else if (ext == 'webp') {
        contentType = MediaType('image', 'webp');
      } else if (ext == 'doc') {
        contentType = MediaType('application', 'msword');
      } else if (ext == 'docx') {
        contentType = MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      } else if (ext == 'txt') {
        contentType = MediaType('text', 'plain');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fileFieldName,
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(fileFieldName, filePath),
      );
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
    );
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(
      response,
      requestToken: token,
      requestGeneration: requestGeneration,
    );
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    String? requestToken,
    required int requestGeneration,
  }) async {
    if (requestToken != null && requestGeneration != _sessionGeneration) {
      throw AuthenticationException('Session changed. Please retry.');
    }
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
      if (requestToken != null) {
        await invalidateSession(
          rejectedToken: requestToken,
          requestGeneration: requestGeneration,
        );
      }
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
