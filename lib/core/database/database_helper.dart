import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../../services/private_local_store.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/water_intake.dart';
import '../../services/health_preferences.dart';

/// New health caches use protected mobile storage or browser memory.
/// Legacy SQLite records are copied into protected storage and verified; source files are preserved.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();
  bool _migrated = false;
  Future<void> _migrate() async {
    if ((await SharedPreferences.getInstance()).getBool(
          'legacy_cache_import_disabled',
        ) ==
        true) {
      return;
    }
    if (_migrated || kIsWeb) return;
    try {
      final location = path.join(await getDatabasesPath(), 'medguard_local.db');
      final candidates = [
        location,
        path.join(await getDatabasesPath(), 'medguard.db'),
      ];
      for (final filename in candidates) {
        if (!await databaseExists(filename)) continue;
        final db = await openDatabase(filename);
        final cache = await HealthPreferences.getInstance();
        final tables = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        )).map((r) => r['name']).toSet();
        if (tables.contains('chat_history')) {
          for (final row in await db.query('chat_history')) {
            await cache.setString(
              'ai_chat_history_${row['userId']}',
              row['data'] as String,
            );
          }
        }
        if (tables.contains('water_intake')) {
          for (final row in await db.query('water_intake')) {
            final key = 'water_logs_${row['userId']}';
            final list = cache.getStringList(key) ?? [];
            final item = WaterIntake.fromMap(row);
            if (!list.any((s) => WaterIntake.fromJson(s).id == item.id)) {
              list.add(item.toJson());
            }
            await cache.setStringList(key, list);
          }
        }
        if (tables.contains('offline_cache')) {
          for (final row in await db.query('offline_cache')) {
            await cache.setString(
              'legacy_offline_${row['key']}',
              row['value'] as String,
            );
          }
        }
        // Keep the original database intact. Verify the protected copy before
        // considering operator-approved cleanup of legacy source files.
        final verified = await HealthPreferences.getInstance();
        if (tables.contains('chat_history')) {
          for (final row in await db.query('chat_history')) {
            if (verified.getString('ai_chat_history_${row['userId']}') !=
                row['data']) {
              throw StateError('Migration verification failed');
            }
          }
        }
        if (tables.contains('water_intake')) {
          for (final row in await db.query('water_intake')) {
            final list =
                verified.getStringList('water_logs_${row['userId']}') ?? [];
            if (!list.any((s) => WaterIntake.fromJson(s).id == row['id'])) {
              throw StateError('Migration verification failed');
            }
          }
        }
        await db.close();
      }
      _migrated = true;
    } catch (_) {
      /* Preserve legacy data and retry later if migration cannot finish. */
    }
  }

  /// Called only after an explicit in-app confirmation. New encrypted backups are
  /// round-trip verified with the OS-protected key before any plaintext source is removed.
  Future<int> cleanupVerifiedLegacyCaches({required bool confirmed}) async {
    if (!confirmed) throw StateError('Explicit confirmation required.');
    if (kIsWeb) return 0;
    final directory = await getDatabasesPath();
    var count = 0;
    for (final basename in ['medguard_local.db', 'medguard.db']) {
      final filename = path.join(directory, basename);
      if (!await databaseExists(filename)) continue;
      final db = await openDatabase(filename);
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        await db.close();
      }
      final original = await File(filename).readAsBytes();
      if (original.length > 50 * 1024 * 1024) {
        throw StateError('Legacy database needs an operator-assisted backup.');
      }
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      final algorithm = AesGcm.with256bits();
      final box = await algorithm.encrypt(
        original,
        secretKey: SecretKey(keyBytes),
      );
      final backup = File('$filename.encrypted-backup');
      await backup.writeAsString(
        jsonEncode({
          'v': 1,
          'nonce': base64Encode(box.nonce),
          'cipher': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
        flush: true,
      );
      final keyName = 'legacy_backup_key_$basename';
      await PrivateLocalStore.write(keyName, base64Encode(keyBytes));
      final savedKey = await PrivateLocalStore.read(keyName);
      if (savedKey == null) throw StateError('Backup key verification failed.');
      final saved = jsonDecode(await backup.readAsString());
      final restored = await algorithm.decrypt(
        SecretBox(
          base64Decode(saved['cipher']),
          nonce: base64Decode(saved['nonce']),
          mac: Mac(base64Decode(saved['mac'])),
        ),
        secretKey: SecretKey(base64Decode(savedKey)),
      );
      if (!listEquals(restored, original)) {
        throw StateError('Backup verification failed.');
      }
      await deleteDatabase(filename);
      count++;
    }
    return count;
  }

  Future<void> saveChatHistory(String userId, List<dynamic> messages) async {
    await _migrate();
    final cache = await HealthPreferences.getInstance();
    await cache.setString(
      'ai_chat_history_$userId',
      jsonEncode(messages.map((m) => m.toMap()).toList()),
    );
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    await _migrate();
    final cache = await HealthPreferences.getInstance();
    final raw = cache.getString('ai_chat_history_$userId');
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
  }

  Future<void> clearChatHistory(String userId) async {
    await _migrate();
    final cache = await HealthPreferences.getInstance();
    await cache.remove('ai_chat_history_$userId');
  }

  Future<void> insertWaterIntake(WaterIntake log) async {
    await _migrate();
    final cache = await HealthPreferences.getInstance();
    final key = 'water_logs_${log.userId}';
    final rows =
        (cache.getStringList(key) ?? [])
            .where((s) => WaterIntake.fromJson(s).id != log.id)
            .toList()
          ..add(log.toJson());
    await cache.setStringList(key, rows);
  }

  Future<List<WaterIntake>> getTodayWaterIntake(String userId) async {
    await _migrate();
    final cache = await HealthPreferences.getInstance();
    final now = DateTime.now();
    return (cache.getStringList('water_logs_$userId') ?? [])
        .map(WaterIntake.fromJson)
        .where(
          (w) =>
              w.userId == userId &&
              w.timestamp.year == now.year &&
              w.timestamp.month == now.month &&
              w.timestamp.day == now.day,
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> deleteTodayWaterIntake(String userId) async {
    await _migrate();
    final cache = await HealthPreferences.getInstance();
    final ids = (await getTodayWaterIntake(userId)).map((w) => w.id).toSet();
    await cache.setStringList(
      'water_logs_$userId',
      (cache.getStringList('water_logs_$userId') ?? [])
          .where((s) => !ids.contains(WaterIntake.fromJson(s).id))
          .toList(),
    );
  }

  Future<void> deleteWaterIntake(String id) async {
    await _migrate();
    final cache = await HealthPreferences.getInstance();
    for (final key
        in cache.getKeys().where((k) => k.startsWith('water_logs_')).toList()) {
      await cache.setStringList(
        key,
        (cache.getStringList(key) ?? [])
            .where((s) => WaterIntake.fromJson(s).id != id)
            .toList(),
      );
    }
  }
}
