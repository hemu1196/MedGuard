import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import 'private_local_store.dart';

/// Only ordinary dose history is queued. Emergency actions are never queued.
class MedicineActionOutbox {
  static Future<void> _tail = Future.value();
  @visibleForTesting
  static void resetForTesting() { _tail = Future.value(); }
  static Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static String _key(String userId) => 'dose_outbox_$userId';
  static Future<List<Map<String, dynamic>>> _read(String userId) async {
    final raw = await PrivateLocalStore.read(_key(userId));
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
  }

  static Future<void> _write(String userId, List<Map<String, dynamic>> rows) =>
      PrivateLocalStore.write(_key(userId), jsonEncode(rows));
  static Future<void> enqueue(
    String userId,
    Map<String, dynamic> action,
  ) => _serial(() async {
    final rows = await _read(userId);
    final identity =
        '${action['medicineId']}|${action['scheduledDate']}|${action['scheduledTime']}';
    // Preserve the first intent until the server confirms it. Conflicting corrections
    // require an explicit workflow rather than silently changing a queued action.
    if (!rows.any((row) => row['identity'] == identity)) {
      rows.add({
        'identity': identity,
        'action': action,
        'attempts': 0,
        'retryAt': 0,
      });
      await _write(userId, rows);
    }
  });
  static Future<int> pendingCount(String userId) =>
      _serial(() async => (await _read(userId)).length);
  static Future<int> flush(
    String userId, {
    bool force = false,
  }) => _serial(() async {
    final api = ApiClient();
    final signedIn = await api.getStoredUser();
    if (signedIn?['_id']?.toString() != userId) return 0;
    final rows = await _read(userId);
    final remaining = <Map<String, dynamic>>[];
    var synced = 0;
    for (final row in rows) {
      if (!force &&
          (row['retryAt'] as int? ?? 0) >
              DateTime.now().millisecondsSinceEpoch) {
        remaining.add(row);
        continue;
      }
      final current = await api.getStoredUser();
      if (current?['_id']?.toString() != userId) return synced;
      try {
        await api.post(
          '/medicines/log',
          body: Map<String, dynamic>.from(row['action']),
        );
        synced++;
      } catch (_) {
        final attempts = ((row['attempts'] as int? ?? 0) + 1).clamp(1, 8);
        row['attempts'] = attempts;
        row['retryAt'] = DateTime.now()
            .add(Duration(seconds: 5 * (1 << attempts)))
            .millisecondsSinceEpoch;
        remaining.add(row);
      }
    }
    // A sign-out/account switch clears protected storage; never recreate the old queue.
    if ((await api.getStoredUser())?['_id']?.toString() == userId) {
      await _write(userId, remaining);
    }
    return synced;
  });
}
