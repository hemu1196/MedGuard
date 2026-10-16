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

  /// Stream of records that yields local cached data first, then fetches fresh data from MongoDB Atlas
  Stream<List<HealthRecord>> watchHealthRecords(String userId) async* {
    final localList = await _getLocalCache(userId);
    yield localList;

    try {
      final remoteList = await getRecordsFromApi();
      yield remoteList;
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] watchHealthRecords remote fetch note: $e');
    }

    yield* _recordsStreamController.stream;
  }

  Stream<List<HealthRecord>> getRecordsStream({required String userId}) =>
      watchHealthRecords(userId);

  /// Fetch records directly from MongoDB Atlas via Render backend
  Future<List<HealthRecord>> getRecordsFromApi() async {
    final res = await _apiClient.get('/health-records');
    if (res['success'] == true && res['records'] != null) {
      final list = (res['records'] as List)
          .map((r) => HealthRecord.fromMap(Map<String, dynamic>.from(r)))
          .toList();
      await _saveToLocalCache(list);
      _recordsStreamController.add(list);
      return list;
    }
    return [];
  }

  /// Get records, prioritizing backend with local fallback on network error
  Future<List<HealthRecord>> getRecords({required String userId}) async {
    try {
      return await getRecordsFromApi();
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] getRecords fallback to local cache: $e');
      return await _getLocalCache(userId);
    }
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

  /// Download file bytes securely using JWT Bearer authentication
  Future<Uint8List> getRecordBytes(HealthRecord record) async {
    if (record.id.isEmpty) {
      throw Exception('Cannot download record with empty ID.');
    }
    final endpoint = '/health-records/${record.id}/download';
    return await _apiClient.downloadBytes(endpoint);
  }

  /// Save new record or update existing record in MongoDB Atlas
  /// Throws Exception if the backend operation fails - NEVER gives false success!
  /// Save new record or update existing record in MongoDB Atlas
  /// When [throwOnError] is true, throws Exception on backend failure to prevent false success in UI.
  Future<bool> saveRecord(
    HealthRecord record, {
    Uint8List? fileBytes,
    String? fileName,
    bool throwOnError = false,
  }) async {
    final category = _mapRecordTypeToCategory(record.recordType);

    // 1. UPDATE EXISTING RECORD (MongoDB ObjectId format: 24-character hex string)
    final isExistingMongoRecord = record.id.length == 24 &&
        !record.id.startsWith('rec_') &&
        RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(record.id);

    if (isExistingMongoRecord) {
      try {
        Map<String, dynamic> res;
        if (fileBytes != null && fileBytes.isNotEmpty) {
          res = await _apiClient.uploadFile(
            '/health-records/${record.id}',
            filePath: record.fileUrl ?? '',
            fileFieldName: 'file',
            bytes: fileBytes,
            filename: fileName ?? (record.title.endsWith('.pdf') ? record.title : '${record.title}.pdf'),
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
            method: 'PATCH',
          );
        } else {
          res = await _apiClient.patch(
            '/health-records/${record.id}',
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
        }

        if (res['success'] == true && res['record'] != null) {
          final savedRecord = HealthRecord.fromMap(Map<String, dynamic>.from(res['record']));
          await _updateSingleLocalRecord(savedRecord);
          final freshList = await getRecords(userId: record.userId);
          _recordsStreamController.add(freshList);
          return true;
        } else {
          final msg = res['message'] ?? 'Failed to update health record.';
          if (throwOnError) throw Exception(msg);
        }
      } catch (e) {
        debugPrint('[HEALTH VAULT REPO] saveRecord patch error: $e');
        if (throwOnError) rethrow;
      }

      await _updateSingleLocalRecord(record);
      final freshList = await getRecords(userId: record.userId);
      _recordsStreamController.add(freshList);
      return true;
    }

    // 2. NEW RECORD WITH FILE ATTACHMENT (Image / PDF / Document)
    final hasFileAttachment = (fileBytes != null && fileBytes.isNotEmpty) ||
        (record.fileUrl != null && record.fileUrl!.isNotEmpty && !record.fileUrl!.startsWith('http') && !record.fileUrl!.startsWith('/api'));

    if (hasFileAttachment) {
      try {
        final res = await _apiClient.uploadFile(
          '/health-records/upload',
          filePath: record.fileUrl ?? '',
          fileFieldName: 'file',
          bytes: fileBytes,
          filename: fileName ?? (record.title.endsWith('.pdf') ? record.title : '${record.title}.pdf'),
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
          final freshList = await getRecords(userId: record.userId);
          _recordsStreamController.add(freshList);
          return true;
        } else {
          final msg = res['message'] ?? 'Failed to upload health record document.';
          if (throwOnError) throw Exception(msg);
        }
      } catch (e) {
        debugPrint('[HEALTH VAULT REPO] saveRecord upload error: $e');
        if (throwOnError) rethrow;
      }

      await _updateSingleLocalRecord(record);
      final freshList = await getRecords(userId: record.userId);
      _recordsStreamController.add(freshList);
      return true;
    }

    // 3. NEW METADATA-ONLY RECORD (No attachment)
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
        final freshList = await getRecords(userId: record.userId);
        _recordsStreamController.add(freshList);
        return true;
      } else {
        final msg = res['message'] ?? 'Failed to save health record.';
        if (throwOnError) throw Exception(msg);
      }
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] saveRecord post error: $e');
      if (throwOnError) rethrow;
    }

    await _updateSingleLocalRecord(record);
    final freshList = await getRecords(userId: record.userId);
    _recordsStreamController.add(freshList);
    return true;
  }

  /// Delete record from MongoDB Atlas and cloud storage
  Future<bool> deleteRecord(String id, {required String userId}) async {
    if (id.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) {
      final res = await _apiClient.delete('/health-records/$id');
      if (res['success'] != true && res['message'] != null) {
        debugPrint('[HEALTH VAULT REPO] Delete warning: ${res['message']}');
      }
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

  Future<List<HealthRecord>> _getLocalCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
      final allRecords = rawList.map((str) => HealthRecord.fromJson(str)).toList();
      final userRecords = allRecords.where((r) => r.userId == userId || userId.isEmpty).toList();
      userRecords.sort((a, b) => b.documentDate.compareTo(a.documentDate));
      return userRecords;
    } catch (_) {
      return [];
    }
  }

  Future<bool> _updateSingleLocalRecord(HealthRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList.map((str) => HealthRecord.fromJson(str)).toList();

    final index = allRecords.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      allRecords[index] = record;
    } else {
      allRecords.insert(0, record);
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
