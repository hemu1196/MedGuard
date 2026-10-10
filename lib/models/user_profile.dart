import 'dart:convert';
import '../core/utils/bmi_calculator.dart';

class UserProfile {
  final String name;
  final DateTime? dateOfBirth;
  final int? _explicitAge;
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
  final bool profileCompleted;

  UserProfile({
    required this.name,
    this.dateOfBirth,
    int? age,
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
    this.profileCompleted = false,
  }) : _explicitAge = age;

  UserProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    int? age,
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
    bool? profileCompleted,
  }) {
    return UserProfile(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? _explicitAge,
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
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }

  int get age {
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int calculatedAge = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        calculatedAge--;
      }
      return calculatedAge >= 0 ? calculatedAge : 0;
    }
    return _explicitAge ?? 0;
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
      'fullName': name,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'height': height,
      'heightCm': double.tryParse(height),
      'weight': weight,
      'weightKg': double.tryParse(weight),
      'bmi': bmi,
      'allergies': allergies,
      'existingConditions': existingConditions,
      'chronicConditions': existingConditions,
      'currentMedications': currentMedications,
      'emergencyMedicalInfo': currentMedications,
      'emergencyContactName': emergencyContactName,
      'emergencyCountryCode': emergencyCountryCode,
      'emergencyPhone': emergencyPhone,
      'phoneNumber': emergencyPhone,
      'emergencyRelationship': emergencyRelationship,
      'profileImagePath': profileImagePath,
      'profilePictureUrl': profileImagePath,
      'profileCompleted': profileCompleted,
      'isProfileComplete': profileCompleted,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    String parseString(dynamic val) {
      if (val is List) return val.join(', ');
      return val?.toString() ?? '';
    }

    DateTime? parseDob(dynamic dobVal) {
      if (dobVal != null && dobVal.toString().isNotEmpty) {
        final d = DateTime.tryParse(dobVal.toString());
        if (d != null) return d;
      }
      return null;
    }

    final parsedDob = parseDob(map['dateOfBirth']);
    final parsedExplicitAge = map['age'] is num ? (map['age'] as num).toInt() : null;
    final parsedName = (map['name'] ?? map['fullName'] ?? '').toString();
    final parsedHeight = (map['height'] ?? map['heightCm'])?.toString() ?? '';
    final parsedWeight = (map['weight'] ?? map['weightKg'])?.toString() ?? '';

    final hasRequired = parsedName.trim().isNotEmpty &&
        parsedHeight.trim().isNotEmpty &&
        parsedWeight.trim().isNotEmpty &&
        (parsedDob != null || (parsedExplicitAge != null && parsedExplicitAge >= 0));

    final isComplete = map['profileCompleted'] == true ||
        map['isProfileComplete'] == true ||
        hasRequired;

    return UserProfile(
      name: parsedName,
      dateOfBirth: parsedDob,
      age: parsedExplicitAge,
      gender: map['gender'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      height: parsedHeight,
      weight: parsedWeight,
      allergies: parseString(map['allergies']),
      existingConditions: parseString(map['existingConditions'] ?? map['chronicConditions']),
      currentMedications: parseString(map['currentMedications'] ?? map['emergencyMedicalInfo']),
      emergencyContactName: map['emergencyContactName'] ?? '',
      emergencyCountryCode: map['emergencyCountryCode'] ?? '+91',
      emergencyPhone: map['emergencyPhone'] ?? map['phoneNumber'] ?? '',
      emergencyRelationship: map['emergencyRelationship'] ?? 'Dad',
      profileImagePath: map['profileImagePath'] ?? map['profilePictureUrl'],
      profileCompleted: isComplete,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(json.decode(source));
}
