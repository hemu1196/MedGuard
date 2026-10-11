import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/core/api/api_client.dart';
import 'package:med_ai/models/user_profile.dart';
import 'package:med_ai/repositories/auth_repository.dart';

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

    test('UserProfile serialization toMap and fromMap works accurately with profileCompleted', () {
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
        profileCompleted: true,
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
      expect(restored.profileCompleted, isTrue);
    });

    test('UserProfile parses age and profileCompleted from MongoDB backend response', () {
      final backendJson = {
        '_id': '60d5ec49f1b2c81234567890',
        'fullName': 'MongoDB User',
        'email': 'mongodb@test.com',
        'age': 25,
        'gender': 'Male',
        'bloodGroup': 'O+',
        'heightCm': 175,
        'weightKg': 70,
        'allergies': ['Penicillin'],
        'chronicConditions': ['None'],
        'emergencyMedicalInfo': 'None',
        'emergencyContactName': 'Contact Person',
        'emergencyPhone': '9876543210',
        'profileCompleted': true,
      };

      final profile = UserProfile.fromMap(backendJson);
      expect(profile.name, equals('MongoDB User'));
      expect(profile.age, equals(25));
      expect(profile.gender, equals('Male'));
      expect(profile.bloodGroup, equals('O+'));
      expect(profile.height, equals('175'));
      expect(profile.weight, equals('70'));
      expect(profile.profileCompleted, isTrue);
    });
  });

  group('Authentication & Token Integration Unit Tests', () {
    test('AuthSession accurately maps token, userId, and properties', () {
      final session = AuthSession(
        token: 'test_jwt_token_abc123',
        userId: 'user_mongodb_id_999',
        email: 'doctor@medguard.dev',
        name: 'Dr. John Doe',
        profileCompleted: true,
        rawUser: {'_id': 'user_mongodb_id_999', 'role': 'user'},
      );

      expect(session.token, equals('test_jwt_token_abc123'));
      expect(session.userId, equals('user_mongodb_id_999'));
      expect(session.uid, equals('user_mongodb_id_999'));
      expect(session.user, isNotNull);
      expect(session['token'], equals('test_jwt_token_abc123'));
      expect(session['userId'], equals('user_mongodb_id_999'));
      expect(session.profileCompleted, isTrue);
    });

    test('ApiClient detects expired JWT tokens correctly', () {
      final client = ApiClient();
      // Valid dummy JWT expiring in the future (exp: 2500000000 -> year 2049)
      const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIxMjMiLCJleHAiOjI1MDAwMDAwMDB9.signature';
      expect(client.isTokenExpired(validToken), isFalse);

      // Expired dummy JWT (exp: 1000000000 -> year 2001)
      const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIxMjMiLCJleHAiOjEwMDAwMDAwMDB9.signature';
      expect(client.isTokenExpired(expiredToken), isTrue);

      // Malformed token considered expired / invalid
      const malformedToken = 'invalid.jwt';
      expect(client.isTokenExpired(malformedToken), isTrue);
    });
  });
}
