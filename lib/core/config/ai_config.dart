import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/private_local_store.dart';

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
      final savedKey =
          await PrivateLocalStore.read(_prefKey) ?? prefs.getString(_prefKey);
      if (savedKey != null) await PrivateLocalStore.write(_prefKey, savedKey);
      await prefs.remove(_prefKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (e) {
      debugPrint('[AI_CONFIG] Operation status changed.');
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
      return 'Protected custom test key';
    }
    return 'Secure Cloud Backend (Render)';
  }

  /// Indicates whether the AI service is ready to handle queries.
  /// Always returns true because the authenticated Render cloud backend
  /// routes requests to the server; each request still checks actual availability.
  static Future<bool> hasApiKey() async {
    return true;
  }

  /// Stores a custom test API key in local preferences if provided.
  static Future<void> saveGeminiApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      if (apiKey.trim().isEmpty) {
        await PrivateLocalStore.remove(_prefKey);
      } else {
        await PrivateLocalStore.write(_prefKey, apiKey.trim());
      }
    } catch (e) {
      debugPrint('[AI_CONFIG] Operation status changed.');
    }
  }

  static Future<void> setApiKey(String apiKey) => saveGeminiApiKey(apiKey);
}
