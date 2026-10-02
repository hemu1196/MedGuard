import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';

class MedicineRepository {
  static const String _medicineKey = 'user_medicines_list';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Exposes a real-time Firestore stream for a user's medicines collection.
  Stream<List<Medicine>> watchMedicines(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Medicine.fromMap(doc.data()))
          .toList();
    });
  }

  Future<List<Medicine>> getMedicines({required String userId}) async {
    // 1. Try Firestore first
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final firestoreMeds = snapshot.docs
            .map((doc) => Medicine.fromMap(doc.data()))
            .toList();

        // Sync local cache
        final prefs = await SharedPreferences.getInstance();
        final rawList = prefs.getStringList(_medicineKey) ?? [];
        final localMeds = rawList
            .map((str) => Medicine.fromJson(str))
            .where((m) => m.userId != userId)
            .toList();
        localMeds.addAll(firestoreMeds);

        final updatedRawList = localMeds.map((m) => m.toJson()).toList();
        await prefs.setStringList(_medicineKey, updatedRawList);

        return firestoreMeds;
      }
    } catch (_) {
      // Offline fallback
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

    // 2. Sync to Cloud Firestore
    try {
      await _firestore
          .collection('users')
          .doc(medicine.userId)
          .collection('medicines')
          .doc(medicine.id)
          .set(medicine.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Offline fallback
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

    // 2. Delete from Cloud Firestore
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(id)
          .delete();
    } catch (_) {
      // Offline fallback
    }

    return localSuccess;
  }
}
