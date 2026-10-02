import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';

class MedicineRepository {
  static const String _medicineKey = 'user_medicines_list';

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

  /// Exposes a real-time stream for a user's medicines collection.
  /// Safely handles unauthenticated/offline states and Firestore errors by falling back to local storage.
  Stream<List<Medicine>> watchMedicines(String userId) async* {
    // Initial emit from local cache for instant UI response
    final localList = await getMedicines(userId: userId);
    yield localList;

    final currentUser = _auth?.currentUser;
    if (_firestore == null || currentUser == null || currentUser.uid != userId) {
      debugPrint('[MEDICINE REPO] User not authenticated with Firebase Auth or UID mismatch. Using local cache.');
      return;
    }

    try {
      yield* _firestore!
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .snapshots()
          .map((snapshot) {
        final firestoreMeds = snapshot.docs
            .map((doc) => Medicine.fromMap(doc.data()))
            .toList();

        // Sync local cache
        _syncLocalCache(userId, firestoreMeds);

        return firestoreMeds;
      }).handleError((error) {
        debugPrint('[MEDICINE REPO] Stream error (permission-denied / network): $error');
        return localList;
      });
    } catch (e) {
      debugPrint('[MEDICINE REPO] Firestore watch failed: $e');
    }
  }

  Future<void> _syncLocalCache(String userId, List<Medicine> firestoreMeds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_medicineKey) ?? [];
      final localMeds = rawList
          .map((str) => Medicine.fromJson(str))
          .where((m) => m.userId != userId)
          .toList();
      localMeds.addAll(firestoreMeds);

      final updatedRawList = localMeds.map((m) => m.toJson()).toList();
      await prefs.setStringList(_medicineKey, updatedRawList);
    } catch (e) {
      debugPrint('[MEDICINE REPO] Failed to sync local cache: $e');
    }
  }

  Future<List<Medicine>> getMedicines({required String userId}) async {
    final currentUser = _auth?.currentUser;
    if (_firestore != null && currentUser != null && currentUser.uid == userId) {
      try {
        final snapshot = await _firestore!
            .collection('users')
            .doc(userId)
            .collection('medicines')
            .get();

        if (snapshot.docs.isNotEmpty) {
          final firestoreMeds = snapshot.docs
              .map((doc) => Medicine.fromMap(doc.data()))
              .toList();

          await _syncLocalCache(userId, firestoreMeds);
          return firestoreMeds;
        }
      } catch (e) {
        debugPrint('[MEDICINE REPO] getMedicines Firestore error (offline fallback): $e');
      }
    }

    // 2. Local SharedPreferences fallback
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_medicineKey) ?? [];
    final allMeds = rawList.map((str) => Medicine.fromJson(str)).toList();
    return allMeds.where((m) => m.userId == userId).toList();
  }

  Future<bool> saveMedicine(Medicine medicine) async {
    // 1. Save locally first
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_medicineKey) ?? [];
    final allMeds = rawList.map((str) => Medicine.fromJson(str)).toList();

    final index = allMeds.indexWhere((m) => m.id == medicine.id);
    if (index >= 0) {
      allMeds[index] = medicine;
    } else {
      allMeds.add(medicine);
    }

    final updatedRawList = allMeds.map((m) => m.toJson()).toList();
    final localSuccess = await prefs.setStringList(_medicineKey, updatedRawList);

    // 2. Sync to Cloud Firestore if authenticated
    final currentUser = _auth?.currentUser;
    if (_firestore != null && currentUser != null && currentUser.uid == medicine.userId) {
      try {
        await _firestore!
            .collection('users')
            .doc(medicine.userId)
            .collection('medicines')
            .doc(medicine.id)
            .set(medicine.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('[MEDICINE REPO] saveMedicine Firestore error (saved locally): $e');
      }
    }

    return localSuccess;
  }

  Future<bool> deleteMedicine(String id, {required String userId}) async {
    // 1. Delete locally
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_medicineKey) ?? [];
    final allMeds = rawList.map((str) => Medicine.fromJson(str)).toList();

    allMeds.removeWhere((m) => m.id == id && m.userId == userId);

    final updatedRawList = allMeds.map((m) => m.toJson()).toList();
    final localSuccess = await prefs.setStringList(_medicineKey, updatedRawList);

    // 2. Delete from Cloud Firestore if authenticated
    final currentUser = _auth?.currentUser;
    if (_firestore != null && currentUser != null && currentUser.uid == userId) {
      try {
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('medicines')
            .doc(id)
            .delete();
      } catch (e) {
        debugPrint('[MEDICINE REPO] deleteMedicine Firestore error (deleted locally): $e');
      }
    }

    return localSuccess;
  }
}
