import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'private_local_store.dart';

/// Adapter for legacy health caches: native OS-protected storage, browser memory.
class HealthPreferences {
  static const _key = 'protected_health_cache_v1';
  static Future<void>? _tail;
  final Map<String, dynamic> _values;
  final int _generation;
  HealthPreferences._(this._values, this._generation);
  static Future<HealthPreferences> getInstance() async {
    final generation = PrivateLocalStore.generation;
    final raw = await PrivateLocalStore.read(_key);
    final values = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw));
    final instance = HealthPreferences._(values, generation);
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(isHealthKey).toList()) {
      if (generation != PrivateLocalStore.generation) {
        return HealthPreferences._({}, generation);
      }
      if (!values.containsKey(key)) {
        final value = prefs.get(key);
        if (value != null) await instance._change(key, value, false);
      }
      await prefs.remove(key);
    }
    if (generation != PrivateLocalStore.generation) {
      return HealthPreferences._({}, generation);
    }
    final fresh = await PrivateLocalStore.read(_key);
    return HealthPreferences._(
      fresh == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(fresh)),
      generation,
    );
  }

  static bool isHealthKey(String key) => [
    'ai_chat_history_',
    'legacy_offline_',
    'user_profile_',
    'user_health',
    'user_medicines',
    'user_doctor_appointments',
    'user_emergency',
    'user_prescriptions',
    'user_family_members',
    'user_water',
    'daily_water',
    'water_',
    'bmi_',
    'emergency_',
    'cached_',
    'medguard_in_app_notifications',
    'medguard_emergency_sos_logs',
    'user_name',
    'user_email',
    'user_height',
    'user_weight',
    'user_blood',
    'user_gender',
  ].any(key.startsWith);
  String? getString(String key) => _values[key] as String?;
  List<String>? getStringList(String key) =>
      _values[key] == null ? null : List<String>.from(_values[key]);
  int? getInt(String key) => _values[key] as int?;
  double? getDouble(String key) => (_values[key] as num?)?.toDouble();
  bool? getBool(String key) => _values[key] as bool?;
  Set<String> getKeys() => _values.keys.toSet();
  dynamic get(String key) => _values[key];
  bool containsKey(String key) => _values.containsKey(key);
  Future<bool> _change(String key, dynamic value, bool remove) async {
    if (_generation != PrivateLocalStore.generation) return false;
    if (remove) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    // Merge independent keys rather than overwriting another repository's cache.
    final result = (_tail ?? Future<void>.value()).then((_) async {
      if (_generation != PrivateLocalStore.generation) return false;
      final raw = await PrivateLocalStore.read(_key);
      final latest = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw));
      if (remove) {
        latest.remove(key);
      } else {
        latest[key] = value;
      }
      await PrivateLocalStore.write(_key, jsonEncode(latest));
      return true;
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<bool> setString(String k, String v) => _change(k, v, false);
  Future<bool> setStringList(String k, List<String> v) => _change(k, v, false);
  Future<bool> setInt(String k, int v) => _change(k, v, false);
  Future<bool> setDouble(String k, double v) => _change(k, v, false);
  Future<bool> setBool(String k, bool v) => _change(k, v, false);
  Future<bool> remove(String k) => _change(k, null, true);
  static void resetForTesting() {
    _tail = null;
  }
}
