import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const String _profileKey = 'user_health_profile';

  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_profileKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }
    try {
      return UserProfile.fromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_profileKey, profile.toJson());
  }

  Future<bool> hasCompletedProfile() async {
    final profile = await getProfile();
    return profile != null && profile.name.trim().isNotEmpty;
  }
}
