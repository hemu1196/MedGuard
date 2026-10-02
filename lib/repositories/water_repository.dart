import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_helper.dart';
import '../models/water_intake.dart';

class WaterRepository {
  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _firestore {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

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
      await DatabaseHelper.instance.deleteTodayWaterIntake(userId);
    } catch (e) {
      debugPrint('[WATER REPO] Reset water error: $e');
    }

    if (_firestore != null) {
      try {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        final snapshot = await _firestore!
            .collection('users')
            .doc(userId)
            .collection('water_intake')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
            .where('timestamp', isLessThanOrEqualTo: endOfDay.toIso8601String())
            .get();

        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[WATER REPO] Reset Firestore water logs error: $e');
      }
    }

    return await getTodayWaterIntake(userId: userId);
  }

  Future<DailyWaterIntake> updateTarget(int targetMl, {required String userId}) async {
    await _setTargetMl(userId, targetMl);
    if (_firestore != null) {
      try {
        await _firestore!.collection('users').doc(userId).set(
          {'waterTargetMl': targetMl},
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('[WATER REPO] Sync target to firestore error: $e');
      }
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

    // 1. Local SQLite / Web storage
    await DatabaseHelper.instance.insertWaterIntake(log);

    // 2. Sync to Cloud Firestore if Firebase is available
    if (_firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('water_intake')
            .doc(log.id)
            .set(log.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('[WATER REPO] Cloud sync error: $e');
      }
    }

    return log;
  }
}
