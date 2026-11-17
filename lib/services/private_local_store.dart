import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Health payloads are OS-protected on mobile. Web uses memory only.
class PrivateLocalStore {
  static int generation = 0;
  static const _storage = FlutterSecureStorage();
  static final Map<String, String> _webMemory = {};
  static Future<String?> read(String key) =>
      kIsWeb ? Future.value(_webMemory[key]) : _storage.read(key: key);
  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      _webMemory[key] = value;
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<void> remove(String key) async {
    _webMemory.remove(key);
    if (!kIsWeb) await _storage.delete(key: key);
  }

  static Future<void> clear() async {
    generation++;
    _webMemory.clear();
    if (!kIsWeb) await _storage.deleteAll();
  }
}
