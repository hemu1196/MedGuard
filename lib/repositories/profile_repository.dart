import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  static const String _profileStoragePrefix = 'user_profile_';
  final ApiClient _apiClient = ApiClient();

  Future<bool> profileExists(String uid) async {
    return hasCompletedProfile(userId: uid);
  }

  Future<UserProfile?> getProfile({required String userId}) async {
    // 1. Try to fetch from MongoDB Atlas backend API
    try {
      final res = await _apiClient.get('/auth/me');
      if (res['success'] == true && res['user'] != null) {
        final profile = UserProfile.fromMap(Map<String, dynamic>.from(res['user']));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_profileStoragePrefix$userId', profile.toJson());
        return profile;
      }
    } catch (e) {
      debugPrint('[PROFILE REPO] getProfile API note: $e');
    }

    // 2. Local SharedPreferences fallback
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_profileStoragePrefix$userId');
    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }
    try {
      return UserProfile.fromJson(jsonStr);
    } catch (e) {
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
    // 1. Sync to MongoDB Atlas Backend API
    try {
      final body = {
        'fullName': profile.name,
        'gender': profile.gender,
        'bloodGroup': profile.bloodGroup,
        'heightCm': double.tryParse(profile.height),
        'weightKg': double.tryParse(profile.weight),
        'allergies': profile.allergies.isNotEmpty ? profile.allergies.split(',').map((s) => s.trim()).toList() : [],
        'chronicConditions': profile.existingConditions.isNotEmpty ? profile.existingConditions.split(',').map((s) => s.trim()).toList() : [],
        'emergencyMedicalInfo': profile.currentMedications,
      };

      await _apiClient.put('/auth/profile', body: body);
    } catch (e) {
      debugPrint('[PROFILE REPO] saveProfile API note: $e');
    }

    // 2. Save locally
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString('$_profileStoragePrefix$userId', profile.toJson());
  }

  Future<bool> hasCompletedProfile({required String userId}) async {
    final profile = await getProfile(userId: userId);
    return profile != null && profile.name.trim().isNotEmpty;
  }
}
