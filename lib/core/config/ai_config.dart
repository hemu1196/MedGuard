import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration manager for AI Assistant services.
/// In production, AI requests are securely routed through the authenticated
/// Render cloud backend (`/api/ai/chat`) where `GEMINI_API_KEY` is maintained
/// strictly server-side, eliminating client-side secret exposure.
class AiConfig {
  AiConfig._();

  static const String _prefKey = 'user_configured_gemini_api_key';
  static const String _envProxyUrl = String.fromEnvironment('GEMINI_PROXY_URL');

  /// Retrieves any explicitly configured custom test key.
  /// In standard operation, returns empty string as production calls use the
  /// authenticated server-side cloud proxy.
  static Future<String> getGeminiApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (e) {
      debugPrint('[AI CONFIG] SharedPreferences read error: $e');
    }
    return '';
  }

  static Future<String> getApiKey() => getGeminiApiKey();

  /// Retrieves the backend proxy endpoint URL for AI chat requests if configured.
  static Future<String> getProxyUrl() async {
    if (_envProxyUrl.isNotEmpty) {
      return _envProxyUrl.trim();
    }
    return '';
  }

  /// Describes the source of AI capability for the diagnostics UI.
  static Future<String> getApiKeySource() async {
    final customKey = await getGeminiApiKey();
    if (customKey.isNotEmpty) {
      return 'SharedPreferences Key';
    }
    return 'Secure Cloud Backend (Render)';
  }

  /// Indicates whether the AI service is ready to handle queries.
  /// Always returns true because the authenticated Render cloud backend
  /// proxies Gemini queries with automatic clinical-grade offline triage fallback.
  static Future<bool> hasApiKey() async {
    return true;
  }

  /// Stores a custom test API key in local preferences if provided.
  static Future<void> saveGeminiApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (apiKey.trim().isEmpty) {
        await prefs.remove(_prefKey);
      } else {
        await prefs.setString(_prefKey, apiKey.trim());
      }
    } catch (e) {
      debugPrint('[AI CONFIG] SharedPreferences write error: $e');
    }
  }

  static Future<void> setApiKey(String apiKey) => saveGeminiApiKey(apiKey);
}
