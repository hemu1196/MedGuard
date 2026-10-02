import 'dart:convert';

class FamilyMember {
  final String id;
  final String userId;
  final String name;
  final String
  relationship; // Mother, Father, Spouse, Son, Daughter, Brother, Sister, Grandfather, Grandmother, Guardian, Other
  final DateTime dateOfBirth;
  final String gender; // Male, Female, Other, Prefer not to say
  final String bloodGroup; // A+, A-, B+, B-, AB+, AB-, O+, O-, Unknown
  final bool noKnownAllergies;
  final String allergies;
  final String existingConditions;
  final String currentMedications;
  final String emergencyCountryCode; // +91, +1, +44, +971
  final String emergencyPhone;
  final String emergencyNotes;
  final String lastMedicineStatus;
  final DateTime lastHealthUpdate;

  FamilyMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.dateOfBirth,
    this.gender = 'Prefer not to say',
    required this.bloodGroup,
    this.noKnownAllergies = false,
    this.allergies = '',
    this.existingConditions = '',
    this.currentMedications = '',
    this.emergencyCountryCode = '+91',
    required this.emergencyPhone,
    this.emergencyNotes = '',
    this.lastMedicineStatus = 'Scheduled',
    required this.lastHealthUpdate,
  });

  int get age {
    final now = DateTime.now();
    int computedAge = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      computedAge--;
    }
    return computedAge.clamp(0, 120);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'relationship': relationship,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'bloodGroup': bloodGroup,
      'noKnownAllergies': noKnownAllergies,
      'allergies': allergies,
      'existingConditions': existingConditions,
      'currentMedications': currentMedications,
      'emergencyCountryCode': emergencyCountryCode,
      'emergencyPhone': emergencyPhone,
      'emergencyNotes': emergencyNotes,
      'lastMedicineStatus': lastMedicineStatus,
      'lastHealthUpdate': lastHealthUpdate.toIso8601String(),
    };
  }

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    DateTime parsedDob = DateTime.now().subtract(
      const Duration(days: 365 * 40),
    );
    if (map['dateOfBirth'] != null) {
      parsedDob = DateTime.tryParse(map['dateOfBirth']) ?? parsedDob;
    } else if (map['age'] != null) {
      final int ageVal = map['age'] ?? 40;
      parsedDob = DateTime.now().subtract(Duration(days: 365 * ageVal));
    }

    return FamilyMember(
      id: map['id'] ?? '',
      userId: map['userId'] ?? 'demo_user',
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? 'Parent',
      dateOfBirth: parsedDob,
      gender: map['gender'] ?? 'Prefer not to say',
      bloodGroup: map['bloodGroup'] ?? 'O+',
      noKnownAllergies: map['noKnownAllergies'] ?? false,
      allergies: map['allergies'] ?? '',
      existingConditions: map['existingConditions'] ?? '',
      currentMedications: map['currentMedications'] ?? '',
      emergencyCountryCode: map['emergencyCountryCode'] ?? '+91',
      emergencyPhone: map['emergencyPhone'] ?? '',
      emergencyNotes: map['emergencyNotes'] ?? '',
      lastMedicineStatus: map['lastMedicineStatus'] ?? 'Scheduled',
      lastHealthUpdate:
          DateTime.tryParse(map['lastHealthUpdate'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory FamilyMember.fromJson(String source) =>
      FamilyMember.fromMap(json.decode(source));
}
