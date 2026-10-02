import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/water_intake.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database?> get database async {
    if (kIsWeb) return null; // SQLite native not used on Web; web fallback handles persistence

    if (_database != null) return _database!;

    // Desktop/Test environment initialization for sqflite_common_ffi BEFORE opening database
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } catch (_) {}
    }

    try {
      _database = await _initDB('medguard_local.db');
      return _database;
    } catch (e) {
      return null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE water_intake (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        amountMl INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_history (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        data TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  // --- AI Chat History Database Operations ---

  Future<void> saveChatHistory(String userId, List<dynamic> messages) async {
    final jsonList = messages.map((m) => m.toMap()).toList();
    final jsonStr = json.encode(jsonList);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_chat_history_$userId', jsonStr);

    if (!kIsWeb) {
      try {
        final db = await instance.database;
        if (db != null) {
          await db.insert(
            'chat_history',
            {
              'id': 'chat_$userId',
              'userId': userId,
              'data': jsonStr,
              'updatedAt': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    if (!kIsWeb) {
      try {
        final db = await instance.database;
        if (db != null) {
          final maps = await db.query(
            'chat_history',
            where: 'userId = ?',
            whereArgs: [userId],
          );
          if (maps.isNotEmpty) {
            final jsonStr = maps.first['data'] as String;
            final decoded = json.decode(jsonStr) as List;
            return decoded.cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('ai_chat_history_$userId');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = json.decode(jsonStr) as List;
        return decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    return [];
  }

  Future<void> clearChatHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_chat_history_$userId');

    if (!kIsWeb) {
      try {
        final db = await instance.database;
        if (db != null) {
          await db.delete(
            'chat_history',
            where: 'userId = ?',
            whereArgs: [userId],
          );
        }
      } catch (_) {}
    }
  }

  Future<void> insertWaterIntake(WaterIntake log) async {
    if (kIsWeb) {
      await _insertWaterIntakeWeb(log);
      return;
    }

    try {
      final db = await instance.database;
      if (db != null) {
        await db.insert(
          'water_intake',
          log.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      }
    } catch (_) {}

    await _insertWaterIntakeWeb(log);
  }

  Future<List<WaterIntake>> getTodayWaterIntake(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    if (kIsWeb) {
      return await _getTodayWaterIntakeWeb(userId, startOfDay, endOfDay);
    }

    try {
      final db = await instance.database;
      if (db != null) {
        final maps = await db.query(
          'water_intake',
          where: 'userId = ? AND timestamp >= ? AND timestamp <= ?',
          whereArgs: [userId, startOfDay.toIso8601String(), endOfDay.toIso8601String()],
          orderBy: 'timestamp DESC',
        );
        return maps.map((m) => WaterIntake.fromMap(m)).toList();
      }
    } catch (_) {}

    return await _getTodayWaterIntakeWeb(userId, startOfDay, endOfDay);
  }

  Future<void> deleteTodayWaterIntake(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    if (kIsWeb) {
      await _deleteTodayWaterIntakeWeb(userId, startOfDay, endOfDay);
      return;
    }

    try {
      final db = await instance.database;
      if (db != null) {
        await db.delete(
          'water_intake',
          where: 'userId = ? AND timestamp >= ? AND timestamp <= ?',
          whereArgs: [userId, startOfDay.toIso8601String(), endOfDay.toIso8601String()],
        );
        return;
      }
    } catch (_) {}

    await _deleteTodayWaterIntakeWeb(userId, startOfDay, endOfDay);
  }

  Future<void> _deleteTodayWaterIntakeWeb(
    String userId,
    DateTime startOfDay,
    DateTime endOfDay,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'water_logs_$userId';
    final existing = prefs.getStringList(key) ?? [];
    final remaining = existing
        .map((s) => WaterIntake.fromJson(s))
        .where((l) {
          final t = l.timestamp;
          return t.isBefore(startOfDay) || t.isAfter(endOfDay);
        })
        .map((l) => l.toJson())
        .toList();
    await prefs.setStringList(key, remaining);
  }

  // Web / Fallback SharedPreferences Storage Helpers
  Future<void> _insertWaterIntakeWeb(WaterIntake log) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'water_logs_${log.userId}';
    final existing = prefs.getStringList(key) ?? [];
    existing.add(log.toJson());
    await prefs.setStringList(key, existing);
  }

  Future<List<WaterIntake>> _getTodayWaterIntakeWeb(
    String userId,
    DateTime startOfDay,
    DateTime endOfDay,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'water_logs_$userId';
    final existing = prefs.getStringList(key) ?? [];
    final logs = existing.map((s) => WaterIntake.fromJson(s)).toList();

    return logs.where((l) {
      if (l.userId != userId) return false;
      final t = l.timestamp;
      final isAfterStart = t.isAfter(startOfDay) || t.isAtSameMomentAs(startOfDay);
      final isBeforeEnd = t.isBefore(endOfDay) || t.isAtSameMomentAs(endOfDay);
      return isAfterStart && isBeforeEnd;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}
