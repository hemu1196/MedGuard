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
      Map<String, dynamic> res;
      try {
        res = await _apiClient.get('/users/me');
      } catch (_) {
        res = await _apiClient.get('/auth/me');
      }

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
    final body = {
      'fullName': profile.name,
      'name': profile.name,
      'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
      'age': profile.age,
      'gender': profile.gender,
      'bloodGroup': profile.bloodGroup,
      'heightCm': double.tryParse(profile.height),
      'weightKg': double.tryParse(profile.weight),
      'allergies': profile.allergies.isNotEmpty
          ? profile.allergies.split(',').map((s) => s.trim()).filter((s) => s.isNotEmpty).toList()
          : [],
      'chronicConditions': profile.existingConditions.isNotEmpty
          ? profile.existingConditions.split(',').map((s) => s.trim()).filter((s) => s.isNotEmpty).toList()
          : [],
      'emergencyMedicalInfo': profile.currentMedications,
      'emergencyContactName': profile.emergencyContactName,
      'emergencyCountryCode': profile.emergencyCountryCode,
      'emergencyPhone': profile.emergencyPhone,
      'emergencyRelationship': profile.emergencyRelationship,
      'profilePictureUrl': profile.profileImagePath,
      'profileCompleted': true,
    };

    Map<String, dynamic> res;
    try {
      res = await _apiClient.patch('/users/me', body: body);
    } catch (_) {
      try {
        res = await _apiClient.put('/auth/profile', body: body);
      } catch (err) {
        debugPrint('[PROFILE REPO ERROR] Save failed: $err');
        rethrow;
      }
    }

    if (res['success'] == true && res['user'] != null) {
      final updatedProfile = UserProfile.fromMap(Map<String, dynamic>.from(res['user']));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_profileStoragePrefix$userId', updatedProfile.toJson());
      
      final currentToken = await _apiClient.getToken();
      if (currentToken != null && currentToken.isNotEmpty) {
        await _apiClient.saveAuthSession(currentToken, Map<String, dynamic>.from(res['user']));
      }
      return true;
    } else {
      throw Exception(res['message'] ?? 'Failed to save profile to server');
    }
  }

  Future<bool> hasCompletedProfile({required String userId}) async {
    final profile = await getProfile(userId: userId);
    return profile != null && profile.profileCompleted;
  }
}

extension IterableExtension<E> on Iterable<E> {
  Iterable<E> filter(bool Function(E element) test) => where(test);
}
