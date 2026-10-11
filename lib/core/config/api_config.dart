class ApiConfig {
  ApiConfig._();

  static const String _defaultProdUrl = 'https://medguard-cqmw.onrender.com';

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultProdUrl,
  );

  /// Root URL of the configured backend (trimmed, without trailing slash)
  static String get baseUrl {
    final raw = _configuredBaseUrl.trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Full API base URL including the `/api` route prefix
  static String get apiUrl => '$baseUrl/api';

  /// Constructs an absolute Uri for any backend path (e.g. `/uploads/file.pdf`)
  static Uri endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  /// Constructs an absolute Uri for an API endpoint (prefixed with `/api`)
  static Uri apiEndpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiUrl$normalizedPath');
  }

  /// Checks if the configured backend is the Render production cloud environment
  static bool get isProduction => baseUrl.contains('onrender.com');
}
