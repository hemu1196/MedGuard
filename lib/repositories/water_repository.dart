import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/database/database_helper.dart';
import '../models/water_intake.dart';

class WaterRepository {
  final ApiClient _apiClient = ApiClient();

  Future<int> getTargetMl(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('water_target_$userId') ?? 2000;
    } catch (e) {
      return 2000;
    }
  }

  Future<void> _setTargetMl(String userId, int targetMl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('water_target_$userId', targetMl);
    } catch (e) {
      debugPrint('[WATER REPO] Error saving target: $e');
    }
  }

  Future<DailyWaterIntake> getTodayWaterIntake({required String userId}) async {
    // 1. Attempt API fetch
    try {
      final res = await _apiClient.get('/wellness/water');
      if (res['success'] == true && res['waterIntake'] != null) {
        final record = res['waterIntake'];
        final targetMl = (record['targetMl'] as num?)?.toInt() ?? 2000;
        final consumedMl = (record['consumedMl'] as num?)?.toInt() ?? 0;
        final logsList = (record['logs'] as List? ?? []).map((l) {
          final amt = (l['amountMl'] as num).toInt();
          return WaterIntake(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: userId,
            amountMl: amt,
            timestamp: DateTime.tryParse(l['timestamp'] ?? '') ?? DateTime.now(),
          );
        }).toList();

        await _setTargetMl(userId, targetMl);

        return DailyWaterIntake(
          userId: userId,
          currentMl: consumedMl,
          targetMl: targetMl,
          logs: logsList,
        );
      }
    } catch (e) {
      debugPrint('[WATER REPO] API fetch note: $e');
    }

    // 2. Local database fallback
    final logs = await getTodayLogs(userId);
    final targetMl = await getTargetMl(userId);
    final currentMl = logs.fold<int>(0, (acc, item) => acc + item.amountMl);

    return DailyWaterIntake(
      userId: userId,
      currentMl: currentMl,
      targetMl: targetMl,
      logs: logs,
    );
  }

  Future<DailyWaterIntake> addWater(int amountMl, {required String userId}) async {
    await logWater(userId, amountMl);
    return await getTodayWaterIntake(userId: userId);
  }

  Future<DailyWaterIntake> resetWater({required String userId}) async {
    try {
      await _apiClient.post('/wellness/water/reset', body: {});
    } catch (e) {
      debugPrint('[WATER REPO] Reset API call error: $e');
    }

    try {
      await DatabaseHelper.instance.deleteTodayWaterIntake(userId);
    } catch (e) {
      debugPrint('[WATER REPO] Reset water error: $e');
    }

    return await getTodayWaterIntake(userId: userId);
  }

  Future<DailyWaterIntake> undoLastWaterLog({required String userId}) async {
    try {
      await _apiClient.post('/wellness/water/undo', body: {});
    } catch (e) {
      debugPrint('[WATER REPO] Undo API call error: $e');
    }

    try {
      final logs = await DatabaseHelper.instance.getTodayWaterIntake(userId);
      if (logs.isNotEmpty) {
        final last = logs.last;
        await DatabaseHelper.instance.deleteWaterIntake(last.id);
      }
    } catch (e) {
      debugPrint('[WATER REPO] Undo local DB error: $e');
    }

    return await getTodayWaterIntake(userId: userId);
  }

  Future<DailyWaterIntake> updateTarget(int targetMl, {required String userId}) async {
    await _setTargetMl(userId, targetMl);
    try {
      await _apiClient.post('/wellness/water', body: {'targetMl': targetMl});
    } catch (e) {
      debugPrint('[WATER REPO] Sync target error: $e');
    }
    return await getTodayWaterIntake(userId: userId);
  }

  Future<List<WaterIntake>> getTodayLogs(String userId) async {
    try {
      final logs = await DatabaseHelper.instance.getTodayWaterIntake(userId);
      return logs;
    } catch (e) {
      debugPrint('[WATER REPO] Local database query error: $e');
      return [];
    }
  }

  Future<WaterIntake> logWater(String userId, int amountMl) async {
    final now = DateTime.now();
    final log = WaterIntake(
      id: '${now.microsecondsSinceEpoch}_${amountMl}_${now.microsecond}',
      userId: userId,
      amountMl: amountMl,
      timestamp: now,
    );

    // Local SQLite / Web storage
    await DatabaseHelper.instance.insertWaterIntake(log);

    // Sync to MongoDB Atlas API
    try {
      await _apiClient.post('/wellness/water', body: {
        'amountMl': amountMl,
      });
    } catch (e) {
      debugPrint('[WATER REPO] API log error: $e');
    }

    return log;
  }
}
