import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_record.dart';
import 'storage_repository.dart';

class HealthRecordRepository {
  static const String _vaultStorageKey = 'user_health_vault_records';

  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Exposes a real-time Firestore stream for a user's health records collection.
  Stream<List<HealthRecord>> watchHealthRecords(String userId) async* {
    // Initial emit from local cache for instant UI response
    final localList = await getRecords(userId: userId);
    yield localList;

    final currentUser = _auth?.currentUser;
    if (_firestore == null || currentUser == null || currentUser.uid != userId) {
      debugPrint('[HEALTH VAULT REPO] User not authenticated with Firebase Auth or UID mismatch. Using local cache.');
      return;
    }

    try {
      yield* _firestore!
          .collection('users')
          .doc(userId)
          .collection('health_records')
          .snapshots()
          .map((snapshot) {
        final records = snapshot.docs
            .map((doc) => HealthRecord.fromMap(doc.data()))
            .toList();
        records.sort((a, b) => b.documentDate.compareTo(a.documentDate));

        // Sync local cache
        _syncLocalCache(userId, records);

        return records;
      }).handleError((error) {
        debugPrint('[HEALTH VAULT REPO] Stream error (permission-denied / network): $error');
        return localList;
      });
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] Firestore watch failed: $e');
    }
  }

  Future<void> _syncLocalCache(String userId, List<HealthRecord> firestoreRecords) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
      final localRecords = rawList
          .map((str) => HealthRecord.fromJson(str))
          .where((r) => r.userId != userId)
          .toList();
      localRecords.addAll(firestoreRecords);

      final updatedRawList = localRecords.map((r) => r.toJson()).toList();
      await prefs.setStringList(_vaultStorageKey, updatedRawList);
    } catch (e) {
      debugPrint('[HEALTH VAULT REPO] Failed to sync local cache: $e');
    }
  }

  Stream<List<HealthRecord>> getRecordsStream({required String userId}) =>
      watchHealthRecords(userId);

  Future<List<HealthRecord>> getRecords({required String userId}) async {
    final currentUser = _auth?.currentUser;
    if (_firestore != null && currentUser != null && currentUser.uid == userId) {
      try {
        final snapshot = await _firestore!
            .collection('users')
            .doc(userId)
            .collection('health_records')
            .get();

        if (snapshot.docs.isNotEmpty) {
          final firestoreRecords = snapshot.docs
              .map((doc) => HealthRecord.fromMap(doc.data()))
              .toList();
          firestoreRecords.sort((a, b) => b.documentDate.compareTo(a.documentDate));

          await _syncLocalCache(userId, firestoreRecords);
          return firestoreRecords;
        }
      } catch (e) {
        debugPrint('[HEALTH VAULT REPO] getRecords Firestore error (offline fallback): $e');
      }
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
    HealthRecord recordToSave = record;

    // 0. Upload attachment to Firebase Storage if it's a local file path
    if (record.fileUrl != null &&
        record.fileUrl!.isNotEmpty &&
        !record.fileUrl!.startsWith('http')) {
      final downloadUrl = await StorageRepository().uploadHealthRecordAttachment(
        userId: record.userId,
        recordId: record.id,
        filePath: record.fileUrl!,
        fileName: 'attachment_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (downloadUrl != null) {
        recordToSave = record.copyWith(fileUrl: downloadUrl);
      }
    }

    // 1. Local update first
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_vaultStorageKey) ?? [];
    final allRecords = rawList
        .map((str) => HealthRecord.fromJson(str))
        .toList();

    final index = allRecords.indexWhere((r) => r.id == recordToSave.id);
    if (index >= 0) {
      allRecords[index] = recordToSave;
    } else {
      allRecords.add(recordToSave);
    }

    final updatedRawList = allRecords.map((r) => r.toJson()).toList();
    final localSuccess = await prefs.setStringList(_vaultStorageKey, updatedRawList);

    // 2. Sync to Cloud Firestore if initialized and authenticated
    final currentUser = _auth?.currentUser;
    if (_firestore != null && currentUser != null && currentUser.uid == recordToSave.userId) {
      try {
        await _firestore!
            .collection('users')
            .doc(recordToSave.userId)
            .collection('health_records')
            .doc(recordToSave.id)
            .set(recordToSave.toMap(), SetOptions(merge: true));
      } catch (_) {
        // Offline fallback: saved locally
      }
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

    // 2. Firestore delete if initialized and authenticated
    final currentUser = _auth?.currentUser;
    if (_firestore != null && currentUser != null && currentUser.uid == userId) {
      try {
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('health_records')
            .doc(id)
            .delete();
      } catch (_) {
        // Offline fallback
      }
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
