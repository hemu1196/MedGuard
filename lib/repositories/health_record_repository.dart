import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/health_record.dart';

class HealthRecordRepository {
  static const String _vaultStorageKey = 'user_health_vault_records';
  final ApiClient _apiClient = ApiClient();

  Stream<List<HealthRecord>> watchHealthRecords(String userId) async* {
    final localList = await getRecords(userId: userId);
    yield localList;

    try {
      final remoteList = await getRecordsFromApi();
      if (remoteList.isNotEmpty) {
        yield remoteList;
      }
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] watchHealthRecords API error: $e');
    }
  }

  Stream<List<HealthRecord>> getRecordsStream({required String userId}) =>
      watchHealthRecords(userId);

  Future<List<HealthRecord>> getRecordsFromApi() async {
    try {
      final res = await _apiClient.get('/health-records');
      if (res['success'] == true && res['records'] != null) {
        final list = (res['records'] as List)
            .map((r) => HealthRecord.fromMap(Map<String, dynamic>.from(r)))
            .toList();
        await _saveToLocalCache(list);
        return list;
      }
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] getRecordsFromApi failed: $e');
    }
    return [];
  }

  Future<List<HealthRecord>> getRecords({required String userId}) async {
    final remoteList = await getRecordsFromApi();
    if (remoteList.isNotEmpty) {
      return remoteList;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList
        .map((str) => HealthRecord.fromJson(str))
        .toList();
    final userRecords = allRecords.where((r) => r.userId == userId || userId.isEmpty).toList();
    userRecords.sort((a, b) => b.documentDate.compareTo(a.documentDate));
    return userRecords;
  }

  Future<List<HealthRecord>> getRecordsByType({
    required HealthRecordType type,
    required String userId,
  }) async {
    final records = await getRecords(userId: userId);
    return records.where((r) => r.recordType == type).toList();
  }

  Future<HealthRecord?> getRecordById(
    String id, {
    required String userId,
  }) async {
    final records = await getRecords(userId: userId);
    try {
      return records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveRecord(HealthRecord record, {Uint8List? fileBytes, String? fileName}) async {
    try {
      if (record.fileUrl != null && record.fileUrl!.isNotEmpty) {
        final categoryMap = {
          HealthRecordType.prescription: 'prescription',
          HealthRecordType.labReport: 'lab',
          HealthRecordType.imaging: 'scan',
        };
        final category = categoryMap[record.recordType] ?? 'other';

        final res = await _apiClient.uploadFile(
          '/health-records/upload',
          filePath: record.fileUrl!,
          fileFieldName: 'file',
          bytes: fileBytes,
          filename: fileName ?? record.title,
          fields: {
            'title': record.title,
            'category': category,
            'notes': record.description,
            'tags': record.tags.join(','),
          },
        );

        if (res['success'] == true && res['record'] != null) {
          final savedRecord = HealthRecord.fromMap(Map<String, dynamic>.from(res['record']));
          await _updateSingleLocalRecord(savedRecord);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] saveRecord API error: $e');
    }

    return await _updateSingleLocalRecord(record);
  }

  Future<bool> deleteRecord(String id, {required String userId}) async {
    try {
      if (id.length == 24) {
        await _apiClient.delete('/health-records/$id');
      }
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] deleteRecord API error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList.map((str) => HealthRecord.fromJson(str)).toList();
    allRecords.removeWhere((r) => r.id == id);
    final updatedRawList = allRecords.map((r) => r.toJson()).toList();
    return await prefs.setStringList(_vaultStorageKey, updatedRawList);
  }

  Future<List<HealthRecord>> searchRecords(
    String query, {
    required String userId,
  }) async {
    final records = await getRecords(userId: userId);
    if (query.trim().isEmpty) return records;

    final q = query.toLowerCase();
    return records.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.doctorName.toLowerCase().contains(q) ||
          r.hospitalName.toLowerCase().contains(q) ||
          r.typeDisplayName.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Future<bool> _updateSingleLocalRecord(HealthRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList.map((str) => HealthRecord.fromJson(str)).toList();

    final index = allRecords.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      allRecords[index] = record;
    } else {
      allRecords.add(record);
    }

    final updatedRawList = allRecords.map((r) => r.toJson()).toList();
    return await prefs.setStringList(_vaultStorageKey, updatedRawList);
  }

  Future<void> _saveToLocalCache(List<HealthRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedRawList = records.map((r) => r.toJson()).toList();
      await prefs.setStringList(_vaultStorageKey, updatedRawList);
    } catch (_) {}
  }
}
