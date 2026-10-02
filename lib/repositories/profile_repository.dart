import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'storage_repository.dart';

class ProfileRepository {
  static const String _profileStoragePrefix = 'user_profile_';

  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Checks whether a profile document exists under users/{uid}/profile/main in Firestore
  Future<bool> profileExists(String uid) async {
    debugPrint('[PROFILE] Checking if profile exists for UID: $uid');
    if (_firestore != null) {
      try {
        final doc = await _firestore!
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('main')
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null && (doc.data()!['name'] as String?)?.isNotEmpty == true) {
          debugPrint('[PROFILE] Profile document exists in Firestore for $uid');
          return true;
        }
      } catch (e) {
        debugPrint('[PROFILE] Firestore profileExists check note: $e');
      }
    }
    return hasCompletedProfile(userId: uid);
  }

  Future<UserProfile?> getProfile({required String userId}) async {
    debugPrint('[PROFILE] Fetching profile for userId: $userId');
    if (_firestore != null) {
      try {
        final doc = await _firestore!
            .collection('users')
            .doc(userId)
            .collection('profile')
            .doc('main')
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          final profile = UserProfile.fromMap(doc.data()!);
          debugPrint('[PROFILE] Profile fetched from Cloud Firestore.');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            '$_profileStoragePrefix$userId',
            profile.toJson(),
          );
          return profile;
        }
      } catch (e) {
        debugPrint('[PROFILE] Cloud Firestore fetch note (local fallback used): $e');
      }
    }

    // 2. Local SharedPreferences fallback
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_profileStoragePrefix$userId');
    if (jsonStr == null || jsonStr.isEmpty) {
      debugPrint('[PROFILE] No profile found locally or in cloud for $userId');
      return null;
    }
    try {
      debugPrint('[PROFILE] Profile loaded from local storage.');
      return UserProfile.fromJson(jsonStr);
    } catch (e) {
      debugPrint('[PROFILE] Error parsing local profile JSON: $e');
      return null;
    }
  }

  Future<bool> createProfile({
    required String uid,
    required UserProfile profile,
  }) async {
    return saveProfile(profile, userId: uid);
  }

  Future<bool> saveProfile(
    UserProfile profile, {
    required String userId,
  }) async {
    debugPrint('[PROFILE] Saving profile for userId: $userId (Name: ${profile.name})');
    UserProfile profileToSave = profile;

    // 0. Upload profile image to Firebase Storage if it's a local file path
    if (profile.profileImagePath != null &&
        profile.profileImagePath!.isNotEmpty &&
        !profile.profileImagePath!.startsWith('http')) {
      final downloadUrl = await StorageRepository().uploadProfileImage(
        userId: userId,
        filePath: profile.profileImagePath!,
      );
      if (downloadUrl != null) {
        profileToSave = profile.copyWith(profileImagePath: downloadUrl);
      }
    }

    // 1. Always save locally first
    final prefs = await SharedPreferences.getInstance();
    final localSuccess = await prefs.setString(
      '$_profileStoragePrefix$userId',
      profileToSave.toJson(),
    );

    // 2. Sync to Cloud Firestore asynchronously with a safety timeout
    if (_firestore != null) {
      try {
        debugPrint('[PROFILE] Syncing profile to Cloud Firestore (users/$userId/profile/main)...');
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('profile')
            .doc('main')
            .set(profileToSave.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
        debugPrint('[PROFILE] Cloud Firestore sync completed successfully.');
      } catch (e) {
        debugPrint('[PROFILE] Cloud Firestore sync note (offline cache active): $e');
      }
    }

    return localSuccess;
  }

  Future<bool> hasCompletedProfile({required String userId}) async {
    final profile = await getProfile(userId: userId);
    final completed = profile != null && profile.name.trim().isNotEmpty;
    debugPrint('[PROFILE] Profile completion check for $userId: $completed');
    return completed;
  }
}
