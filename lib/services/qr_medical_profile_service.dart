import 'dart:convert';
import '../models/user_profile.dart';

class QrMedicalProfilePayload {
  final String name;
  final int age;
  final String bloodGroup;
  final String allergies;
  final String existingConditions;
  final String currentMedications;
  final String emergencyContact;

  QrMedicalProfilePayload({
    required this.name,
    required this.age,
    required this.bloodGroup,
    required this.allergies,
    required this.existingConditions,
    required this.currentMedications,
    required this.emergencyContact,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'existingConditions': existingConditions,
      'currentMedications': currentMedications,
      'emergencyContact': emergencyContact,
    };
  }

  String toJsonString() => json.encode(toMap());
}

class QrMedicalProfileService {
  QrMedicalProfilePayload generatePayload(UserProfile? profile) {
    if (profile == null || profile.name.isEmpty) {
      return QrMedicalProfilePayload(
        name: 'User Medical Profile',
        age: 0,
        bloodGroup: 'Not Specified',
        allergies: 'None',
        existingConditions: 'None',
        currentMedications: 'None',
        emergencyContact: 'No emergency contact configured.',
      );
    }

    final hasEmergencyContact = profile.emergencyPhone.trim().isNotEmpty;
    final emergencyInfo = hasEmergencyContact
        ? '${profile.emergencyContactName.isNotEmpty ? profile.emergencyContactName : "Emergency Contact"} (${profile.emergencyCountryCode} ${profile.emergencyPhone})'
        : 'No emergency contact configured.';

    return QrMedicalProfilePayload(
      name: profile.name,
      age: profile.age,
      bloodGroup: profile.bloodGroup.isNotEmpty
          ? profile.bloodGroup
          : 'Not Specified',
      allergies: profile.allergies.isNotEmpty ? profile.allergies : 'None',
      existingConditions: profile.existingConditions.isNotEmpty
          ? profile.existingConditions
          : 'None',
      currentMedications: profile.currentMedications.isNotEmpty
          ? profile.currentMedications
          : 'None',
      emergencyContact: emergencyInfo,
    );
  }
}
