import 'dart:convert';
import '../core/utils/bmi_calculator.dart';

class UserProfile {
  final String name;
  final DateTime? dateOfBirth;
  final String gender;
  final String bloodGroup;
  final String height;
  final String weight;
  final String allergies;
  final String existingConditions;
  final String currentMedications;
  final String emergencyContactName;
  final String emergencyCountryCode;
  final String emergencyPhone;
  final String emergencyRelationship;
  final String? profileImagePath;

  UserProfile({
    required this.name,
    this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.height,
    required this.weight,
    required this.allergies,
    required this.existingConditions,
    required this.currentMedications,
    required this.emergencyContactName,
    required this.emergencyCountryCode,
    required this.emergencyPhone,
    this.emergencyRelationship = 'Dad',
    this.profileImagePath,
  });

  UserProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? height,
    String? weight,
    String? allergies,
    String? existingConditions,
    String? currentMedications,
    String? emergencyContactName,
    String? emergencyCountryCode,
    String? emergencyPhone,
    String? emergencyRelationship,
    String? profileImagePath,
  }) {
    return UserProfile(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      allergies: allergies ?? this.allergies,
      existingConditions: existingConditions ?? this.existingConditions,
      currentMedications: currentMedications ?? this.currentMedications,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyCountryCode: emergencyCountryCode ?? this.emergencyCountryCode,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      emergencyRelationship: emergencyRelationship ?? this.emergencyRelationship,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }

  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  double get bmi {
    final h = double.tryParse(height) ?? 0.0;
    final w = double.tryParse(weight) ?? 0.0;
    return BmiCalculator.calculateBMI(heightCm: h, weightKg: w);
  }

  String get bmiCategory => BmiCalculator.getBMICategory(bmi, age: age);

  String get bmiGuidance => BmiCalculator.getBMIGuidance(bmi, age: age);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'bloodGroup': bloodGroup,
      'height': height,
      'weight': weight,
      'bmi': bmi,
      'allergies': allergies,
      'existingConditions': existingConditions,
      'currentMedications': currentMedications,
      'emergencyContactName': emergencyContactName,
      'emergencyCountryCode': emergencyCountryCode,
      'emergencyPhone': emergencyPhone,
      'emergencyRelationship': emergencyRelationship,
      'profileImagePath': profileImagePath,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    String parseListOrString(dynamic val) {
      if (val is List) return val.join(', ');
      return val?.toString() ?? '';
    }

    return UserProfile(
      name: map['name'] ?? map['fullName'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.tryParse(map['dateOfBirth'])
          : (map['age'] is num ? DateTime.now().subtract(Duration(days: (map['age'] as num).toInt() * 365)) : null),
      gender: map['gender'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      height: (map['height'] ?? map['heightCm'])?.toString() ?? '',
      weight: (map['weight'] ?? map['weightKg'])?.toString() ?? '',
      allergies: parseListOrString(map['allergies']),
      existingConditions: parseListOrString(map['existingConditions'] ?? map['chronicConditions']),
      currentMedications: map['currentMedications'] ?? map['emergencyMedicalInfo'] ?? '',
      emergencyContactName: map['emergencyContactName'] ?? '',
      emergencyCountryCode: map['emergencyCountryCode'] ?? '+91',
      emergencyPhone: map['emergencyPhone'] ?? map['phoneNumber'] ?? '',
      emergencyRelationship: map['emergencyRelationship'] ?? 'Dad',
      profileImagePath: map['profileImagePath'] ?? map['profilePictureUrl'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(json.decode(source));
}
