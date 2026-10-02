import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/models/user_profile.dart';

void main() {
  group('UserProfile Unit Tests', () {
    test('Calculates user age dynamically from dateOfBirth', () {
      final dob = DateTime(2000, 5, 15);
      final profile = UserProfile(
        name: 'Alex Johnson',
        dateOfBirth: dob,
        gender: 'Female',
        bloodGroup: 'A+',
        height: '165',
        weight: '60',
        allergies: 'None',
        existingConditions: 'None',
        currentMedications: 'None',
        emergencyContactName: 'Sam Johnson',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
        emergencyRelationship: 'Mother',
      );

      final expectedAge = DateTime.now().year - 2000 -
          ((DateTime.now().month < 5 || (DateTime.now().month == 5 && DateTime.now().day < 15)) ? 1 : 0);
      expect(profile.age, equals(expectedAge));
    });

    test('Calculates BMI dynamically from height and weight strings', () {
      final profile = UserProfile(
        name: 'Rohan Test',
        gender: 'Male',
        bloodGroup: 'O+',
        height: '174',
        weight: '52',
        allergies: 'None',
        existingConditions: 'None',
        currentMedications: 'None',
        emergencyContactName: 'Parent',
        emergencyCountryCode: '+91',
        emergencyPhone: '9123456789',
        emergencyRelationship: 'Dad',
      );

      expect(profile.bmi, equals(17.2));
      expect(profile.bmiCategory, equals('Underweight'));
    });

    test('UserProfile serialization toMap and fromMap works accurately', () {
      final dob = DateTime(1995, 10, 20);
      final original = UserProfile(
        name: 'User Alpha',
        dateOfBirth: dob,
        gender: 'Male',
        bloodGroup: 'B+',
        height: '180',
        weight: '75',
        allergies: 'Peanuts',
        existingConditions: 'Asthma',
        currentMedications: 'Inhaler',
        emergencyContactName: 'Jane Alpha',
        emergencyCountryCode: '+1',
        emergencyPhone: '5551234567',
        emergencyRelationship: 'Spouse',
        profileImagePath: '/path/to/avatar.jpg',
      );

      final map = original.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.name, equals('User Alpha'));
      expect(restored.gender, equals('Male'));
      expect(restored.bloodGroup, equals('B+'));
      expect(restored.height, equals('180'));
      expect(restored.weight, equals('75'));
      expect(restored.emergencyRelationship, equals('Spouse'));
      expect(restored.profileImagePath, equals('/path/to/avatar.jpg'));
    });
  });
}
