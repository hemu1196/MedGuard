import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/health_preferences.dart';
import '../core/api/api_client.dart';
import '../models/medicine.dart';
import '../services/notification_service.dart';
import '../services/medicine_action_outbox.dart';

class MedicineRepository {
  static const String _medicineKey = 'user_medicines_list';
  final ApiClient _apiClient = ApiClient();

  static final StreamController<List<Medicine>> _medicinesStreamController =
      StreamController<List<Medicine>>.broadcast();

  /// Watch medicines stream backed by MongoDB Atlas with local fallback and real-time broadcast
  Stream<List<Medicine>> watchMedicines(String userId) async* {
    final localList = await _getLocalCache(userId);
    yield localList;

    try {
      final remoteList = await getMedicinesFromApi();
      if (remoteList.isNotEmpty) {
        yield remoteList;
      }
    } catch (e) {
      debugPrint('[MEDICINE REPO] watchMedicines API error: $e');
    }

    yield* _medicinesStreamController.stream;
  }

  Future<List<Medicine>> getMedicinesFromApi() async {
    try {
      final user = await _apiClient.getStoredUser();
      final userId = user?['_id']?.toString();
      if (userId != null) {
        unawaited(MedicineActionOutbox.flush(userId).then<void>((_) {}, onError: (Object _) {}));
      }
      final res = await _apiClient.get('/medicines');
      if (res['success'] == true && res['medicines'] != null) {
        final list = (res['medicines'] as List)
            .map((m) => Medicine.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await _saveToLocalCache(list);
        _medicinesStreamController.add(list);
        return list;
      }
    } catch (e) {
      debugPrint('[MEDICINE REPO] getMedicinesFromApi failed: $e');
    }
    return [];
  }

  Future<List<Medicine>> getMedicines({required String userId}) async {
    final remoteList = await getMedicinesFromApi();
    if (remoteList.isNotEmpty) {
      return remoteList;
    }
    return await _getLocalCache(userId);
  }

  Future<List<Medicine>> _getLocalCache(String userId) async {
    final prefs = await HealthPreferences.getInstance();
    final key = '${_medicineKey}_$userId';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_medicineKey) ?? [];
    final allMeds = rawList.map((str) => Medicine.fromJson(str)).toList();
    return allMeds.where((m) => m.userId == userId || userId.isEmpty || m.userId.isEmpty).toList();
  }

  /// Save new medicine or update existing medicine in MongoDB Atlas and local cache.
  /// Returns the saved medicine with its canonical MongoDB _id.
  Future<Medicine?> saveMedicine(Medicine medicine) async {
    // 1. Save to MongoDB Atlas Backend
    try {
      final body = {
        'name': medicine.name,
        'dosage': medicine.dosage,
        'times': medicine.reminderTimes,
        'frequency': medicine.frequency,
        'startDate': medicine.startDate?.toIso8601String(), 'endDate': medicine.endDate?.toIso8601String(), 'weekdays': medicine.weekdays,
        'dosageQuantity': medicine.dosageQuantity, 'refillThreshold': medicine.refillThreshold,
        'totalStock': medicine.quantityAvailable,
        'remainingStock': medicine.quantityAvailable,
        'instructions': medicine.notes,
      };

      Map<String, dynamic> res;
      if (medicine.id.isNotEmpty && medicine.id.length == 24) {
        res = await _apiClient.put('/medicines/${medicine.id}', body: body);
      } else {
        res = await _apiClient.post('/medicines', body: body);
      }

      if (res['success'] == true && res['medicine'] != null) {
        final savedMed = Medicine.fromMap(Map<String, dynamic>.from(res['medicine']));
        await _updateSingleLocalMed(savedMed);
        final fresh = await _getLocalCache(medicine.userId);
        _medicinesStreamController.add(fresh);
        return savedMed;
      }
    } catch (e) {
      debugPrint('[MEDICINE REPO] saveMedicine API error (falling back to local): $e');
    }

    // 2. Local SharedPreferences fallback
    await _updateSingleLocalMed(medicine);
    final fresh = await _getLocalCache(medicine.userId);
    _medicinesStreamController.add(fresh);
    return medicine;
  }

  static String _canonicalTime(String value) { final (hour, minute) = NotificationService.parseTimeParts(value); return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'; }

  Future<bool> logMedicationDose({
    required String medicineId,
    required String scheduledTime,
    required String status, // 'taken' or 'skipped'
    String? missedReason,
    DateTime? scheduledDate,
  }) async {
    final user = await _apiClient.getStoredUser();
    final userId = user?['_id']?.toString() ?? '';
    if (userId.isEmpty) return false;
    final date = scheduledDate ?? DateTime.now();
    final action = <String, dynamic>{
      'medicineId': medicineId, 'scheduledTime': _canonicalTime(scheduledTime), 'status': status,
      'scheduledDate': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'missedReason': ?missedReason,
    };
    // Persist first so process termination or a timeout cannot lose the action.
    await MedicineActionOutbox.enqueue(userId, action);
    await MedicineActionOutbox.flush(userId, force: true);
    return await MedicineActionOutbox.pendingCount(userId) == 0;
  }

  /// Deletes a medicine from MongoDB Atlas and local cache.
  Future<bool> deleteMedicine(String id, {required String userId}) async {
    bool remoteSuccess = false;
    try {
      if (id.length == 24) {
        final res = await _apiClient.delete('/medicines/$id');
        remoteSuccess = res['success'] == true;
      }
    } catch (e) {
      debugPrint('[MEDICINE REPO] deleteMedicine API error: $e');
    }

    // Update local cache
    bool localSuccess = false;
    try {
      final prefs = await HealthPreferences.getInstance();
      final key = '${_medicineKey}_$userId';
      final rawList = prefs.getStringList(key) ?? prefs.getStringList(_medicineKey) ?? [];
      final allMeds = rawList.map((str) => Medicine.fromJson(str)).toList();
      allMeds.removeWhere((m) => m.id == id);
      final updatedRawList = allMeds.map((m) => m.toJson()).toList();
      await prefs.setStringList(key, updatedRawList);
      await prefs.setStringList(_medicineKey, updatedRawList);

      _medicinesStreamController.add(allMeds);
      localSuccess = true;
    } catch (e) {
      debugPrint('[MEDICINE REPO] deleteMedicine local update error: $e');
    }

    return remoteSuccess || localSuccess;
  }

  Future<bool> _updateSingleLocalMed(Medicine medicine) async {
    final prefs = await HealthPreferences.getInstance();
    final key = '${_medicineKey}_${medicine.userId}';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_medicineKey) ?? [];
    final allMeds = rawList.map((str) => Medicine.fromJson(str)).toList();

    final index = allMeds.indexWhere((m) => m.id == medicine.id);
    if (index >= 0) {
      allMeds[index] = medicine;
    } else {
      allMeds.insert(0, medicine);
    }

    final updatedRawList = allMeds.map((m) => m.toJson()).toList();
    await prefs.setStringList(key, updatedRawList);
    return await prefs.setStringList(_medicineKey, updatedRawList);
  }

  Future<void> _saveToLocalCache(List<Medicine> meds) async {
    try {
      final prefs = await HealthPreferences.getInstance();
      final updatedRawList = meds.map((m) => m.toJson()).toList();
      await prefs.setStringList(_medicineKey, updatedRawList);
    } catch (_) {}
  }
}
