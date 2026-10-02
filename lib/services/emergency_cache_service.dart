import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class EmergencyCachedData {
  final String userName;
  final String bloodGroup;
  final String allergies;
  final String conditions;
  final String medicines;
  final String emergencyContactName;
  final String emergencyPhone;

  EmergencyCachedData({
    required this.userName,
    required this.bloodGroup,
    required this.allergies,
    required this.conditions,
    required this.medicines,
    required this.emergencyContactName,
    required this.emergencyPhone,
  });
}

class EmergencyCacheService {
  Future<EmergencyCachedData> getCachedEmergencyProfile(
    UserProfile? profile,
  ) async {
    if (profile != null && profile.name.isNotEmpty) {
      final hasPhone = profile.emergencyPhone.trim().isNotEmpty;
      return EmergencyCachedData(
        userName: profile.name,
        bloodGroup: profile.bloodGroup.isNotEmpty ? profile.bloodGroup : 'Not Specified',
        allergies: profile.allergies.isNotEmpty
            ? profile.allergies
            : 'None Reported',
        conditions: profile.existingConditions.isNotEmpty
            ? profile.existingConditions
            : 'None',
        medicines: profile.currentMedications.isNotEmpty
            ? profile.currentMedications
            : 'None',
        emergencyContactName: profile.emergencyContactName.isNotEmpty
            ? profile.emergencyContactName
            : 'Emergency Contact',
        emergencyPhone: hasPhone
            ? '${profile.emergencyCountryCode} ${profile.emergencyPhone}'
            : 'No emergency contact configured.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedPhone = prefs.getString('cached_emergency_phone') ?? '';
    return EmergencyCachedData(
      userName: prefs.getString('cached_user_name') ?? 'Patient Profile',
      bloodGroup: prefs.getString('cached_blood_group') ?? 'Not Specified',
      allergies: prefs.getString('cached_allergies') ?? 'None Reported',
      conditions: prefs.getString('cached_conditions') ?? 'None',
      medicines: prefs.getString('cached_medicines') ?? 'None',
      emergencyContactName:
          prefs.getString('cached_emergency_name') ?? 'Emergency Contact',
      emergencyPhone: cachedPhone.isNotEmpty
          ? cachedPhone
          : 'No emergency contact configured.',
    );
  }
}
