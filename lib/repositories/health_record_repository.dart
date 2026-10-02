import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_record.dart';

class HealthRecordRepository {
  static const String _vaultStorageKey = 'user_health_vault_records';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Exposes a real-time Firestore stream for a user's health records collection.
  Stream<List<HealthRecord>> watchHealthRecords(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('health_records')
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => HealthRecord.fromMap(doc.data()))
          .toList();
      records.sort((a, b) => b.documentDate.compareTo(a.documentDate));
      return records;
    });
  }

  Stream<List<HealthRecord>> getRecordsStream({required String userId}) =>
      watchHealthRecords(userId);

  Future<List<HealthRecord>> getRecords({required String userId}) async {
    // 1. Try Firestore first
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_records')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final firestoreRecords = snapshot.docs
            .map((doc) => HealthRecord.fromMap(doc.data()))
            .toList();
        firestoreRecords.sort((a, b) => b.documentDate.compareTo(a.documentDate));

        // Update local SharedPreferences cache
        final prefs = await SharedPreferences.getInstance();
        final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
        final localRecords = rawList
            .map((str) => HealthRecord.fromJson(str))
            .where((r) => r.userId != userId)
            .toList();
        localRecords.addAll(firestoreRecords);

        final updatedRawList = localRecords.map((r) => r.toJson()).toList();
        await prefs.setStringList(_vaultStorageKey, updatedRawList);

        return firestoreRecords;
      }
    } catch (_) {
      // Fallback to local cache if offline or error
    }

    // 2. Local SharedPreferences fallback
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList
        .map((str) => HealthRecord.fromJson(str))
        .toList();
    final userRecords = allRecords.where((r) => r.userId == userId).toList();
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

  Future<bool> saveRecord(HealthRecord record) async {
    // 1. Local update first
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList
        .map((str) => HealthRecord.fromJson(str))
        .toList();

    final index = allRecords.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      allRecords[index] = record;
    } else {
      allRecords.add(record);
    }

    final updatedRawList = allRecords.map((r) => r.toJson()).toList();
    final localSuccess = await prefs.setStringList(_vaultStorageKey, updatedRawList);

    // 2. Sync to Cloud Firestore
    try {
      await _firestore
          .collection('users')
          .doc(record.userId)
          .collection('health_records')
          .doc(record.id)
          .set(record.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Offline fallback: saved locally
    }

    return localSuccess;
  }

  Future<bool> deleteRecord(String id, {required String userId}) async {
    // 1. Local delete
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList
        .map((str) => HealthRecord.fromJson(str))
        .toList();

    allRecords.removeWhere((r) => r.id == id && r.userId == userId);

    final updatedRawList = allRecords.map((r) => r.toJson()).toList();
    final localSuccess = await prefs.setStringList(_vaultStorageKey, updatedRawList);

    // 2. Firestore delete
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_records')
          .doc(id)
          .delete();
    } catch (_) {
      // Offline fallback
    }

    return localSuccess;
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
}
