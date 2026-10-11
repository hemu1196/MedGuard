import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/health_record.dart';

class HealthRecordRepository {
  static const String _vaultStorageKey = 'user_health_vault_records';
  final ApiClient _apiClient = ApiClient();

  static final StreamController<List<HealthRecord>> _recordsStreamController =
      StreamController<List<HealthRecord>>.broadcast();

  String _mapRecordTypeToCategory(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.prescription:
        return 'prescription';
      case HealthRecordType.labReport:
        return 'lab';
      case HealthRecordType.imaging:
        return 'scan';
      case HealthRecordType.vaccination:
        return 'vaccination';
      case HealthRecordType.consultation:
        return 'consultation';
      case HealthRecordType.medicalReport:
        return 'medical_report';
      case HealthRecordType.allergy:
        return 'allergy';
      case HealthRecordType.dischargeSummary:
        return 'discharge_summary';
      case HealthRecordType.other:
        return 'other';
    }
  }

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

    yield* _recordsStreamController.stream;
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

  Future<bool> saveRecord(
    HealthRecord record, {
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final category = _mapRecordTypeToCategory(record.recordType);
    bool savedToCloud = false;

    // 1. If file bytes or path are present, perform multipart upload
    final hasFile = (fileBytes != null && fileBytes.isNotEmpty) ||
        (record.fileUrl != null && record.fileUrl!.isNotEmpty && !record.fileUrl!.startsWith('http'));

    if (hasFile) {
      try {
        final res = await _apiClient.uploadFile(
          '/health-records/upload',
          filePath: record.fileUrl ?? '',
          fileFieldName: 'file',
          bytes: fileBytes,
          filename: fileName ?? record.title,
          fields: {
            'title': record.title,
            'category': category,
            'recordType': record.recordType.name,
            'doctorName': record.doctorName,
            'hospitalName': record.hospitalName,
            'documentDate': record.documentDate.toIso8601String(),
            'notes': record.description,
            'tags': record.tags.join(','),
          },
        );

        if (res['success'] == true && res['record'] != null) {
          final savedRecord = HealthRecord.fromMap(Map<String, dynamic>.from(res['record']));
          await _updateSingleLocalRecord(savedRecord);
          savedToCloud = true;
        }
      } catch (e) {
        debugPrint('[HEALTH VAULT REPO] uploadFile error: $e');
      }
    } else {
      // 2. Metadata / note-only record (e.g. AI summary, doctor note without physical file)
      try {
        final res = await _apiClient.post(
          '/health-records',
          body: {
            'title': record.title,
            'category': category,
            'recordType': record.recordType.name,
            'doctorName': record.doctorName,
            'hospitalName': record.hospitalName,
            'documentDate': record.documentDate.toIso8601String(),
            'notes': record.description,
            'tags': record.tags,
          },
        );

        if (res['success'] == true && res['record'] != null) {
          final savedRecord = HealthRecord.fromMap(Map<String, dynamic>.from(res['record']));
          await _updateSingleLocalRecord(savedRecord);
          savedToCloud = true;
        }
      } catch (e) {
        debugPrint('[HEALTH VAULT REPO] post /health-records error: $e');
      }
    }

    if (!savedToCloud) {
      await _updateSingleLocalRecord(record);
    }

    // Refresh and notify broadcast listeners
    final freshList = await getRecords(userId: record.userId);
    _recordsStreamController.add(freshList);
    return true;
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
    await prefs.setStringList(_vaultStorageKey, updatedRawList);

    final freshList = await getRecords(userId: userId);
    _recordsStreamController.add(freshList);
    return true;
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
