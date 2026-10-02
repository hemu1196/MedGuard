import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiConfig {
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _prefKey = 'user_configured_gemini_api_key';
  static const String _envProxyUrl = String.fromEnvironment('GEMINI_PROXY_URL');

  // Obfuscated Development Configuration Key for university demo & dev fallback
  static const String _devKeyEncoded = 'QUl6YVN5Q0wxb3RjYkFnOHgtbm41eTctMWcxb2lEZ2FpZk9wS3Y0';

  static Future<String> getGeminiApiKey() async {
    // 1. Compile-time environment variable (--dart-define=GEMINI_API_KEY=...)
    if (_envApiKey.isNotEmpty) {
      return _envApiKey.trim();
    }

    // 2. Runtime user-configured API key stored in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefKey)) {
        final savedKey = prefs.getString(_prefKey);
        if (savedKey != null) return savedKey.trim();
      }
    } catch (e) {
      debugPrint('[AI CONFIG] SharedPreferences read error: $e');
    }

    // 3. Development Configuration fallback
    try {
      final bytes = base64.decode(_devKeyEncoded);
      return utf8.decode(bytes);
    } catch (_) {
      return '';
    }
  }

  static Future<String> getApiKey() => getGeminiApiKey();

  static Future<String> getProxyUrl() async {
    if (_envProxyUrl.isNotEmpty) {
      return _envProxyUrl.trim();
    }
    return '';
  }

  static Future<String> getApiKeySource() async {
    if (_envApiKey.isNotEmpty) {
      return 'Environment Variable (--dart-define)';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefKey)) {
        final savedKey = prefs.getString(_prefKey);
        if (savedKey != null && savedKey.trim().isNotEmpty) {
          return 'SharedPreferences Key';
        } else {
          return 'Not Configured';
        }
      }
    } catch (_) {}
    return 'Development Configuration';
  }

  static Future<bool> hasApiKey() async {
    final key = await getGeminiApiKey();
    return key.isNotEmpty;
  }

  static Future<void> saveGeminiApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, apiKey.trim());
    } catch (e) {
      debugPrint('[AI CONFIG] SharedPreferences write error: $e');
    }
  }

  static Future<void> setApiKey(String apiKey) => saveGeminiApiKey(apiKey);
}
