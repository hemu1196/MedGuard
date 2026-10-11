import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/models/hospital.dart';
import 'package:med_ai/models/emergency_contact.dart';

void main() {
  group('Hospital and HealthcareCategory Tests', () {
    test('HealthcareCategory parses correctly from strings and attributes', () {
      expect(HealthcareCategory.fromString('hospital'), HealthcareCategory.hospital);
      expect(HealthcareCategory.fromString('emergency_department'), HealthcareCategory.emergencyDepartment);
      expect(HealthcareCategory.fromString('clinic'), HealthcareCategory.clinic);
      expect(HealthcareCategory.fromString('pharmacy'), HealthcareCategory.pharmacy);
      expect(HealthcareCategory.fromString('primary_health_centre'), HealthcareCategory.primaryHealthCentre);
      expect(HealthcareCategory.fromString('unknown_type'), HealthcareCategory.otherHealthcareFacility);
    });

    test('Hospital model retains valid emergency verification and phone', () {
      final hospital = Hospital(
        id: 'osm-node-101',
        source: 'osm',
        sourcePlaceId: '101',
        name: 'Apollo Speciality Hospital',
        category: HealthcareCategory.hospital,
        latitude: 12.9716,
        longitude: 77.5946,
        address: '14th Cross, Malleshwaram, Bangalore',
        phoneNumber: '+91 80 2345 6789',
        emergencyServiceVerified: true,
        emergencyVerificationSource: 'osm_tag_emergency=yes',
        openingHours: '24/7',
        distanceMeters: 1250,
        isDemoData: false,
      );

      expect(hospital.hasValidPhone, isTrue);
      expect(hospital.dialablePhone, '+918023456789');
      expect(hospital.displayPhone, '+91 80 2345 6789');
      expect(hospital.emergencyServiceVerified, isTrue);
      expect(hospital.distanceKm, 1.3);
      expect(hospital.category.displayName, 'Hospital');
    });

    test('Hospital model handles unverified emergency services and missing phone gracefully', () {
      final clinic = Hospital(
        id: 'osm-node-202',
        source: 'osm',
        sourcePlaceId: '202',
        name: 'Neighborhood Care Clinic',
        category: HealthcareCategory.clinic,
        latitude: 12.9800,
        longitude: 77.6000,
        address: 'MG Road, Bangalore',
        phoneNumber: null,
        emergencyServiceVerified: false,
        emergencyVerificationSource: 'osm_unverified',
        distanceMeters: 450,
      );

      expect(clinic.hasValidPhone, isFalse);
      expect(clinic.displayPhone, 'Phone number unavailable');
      expect(clinic.dialablePhone, isNull);
      expect(clinic.emergencyServiceVerified, isFalse);
      expect(clinic.openingHoursDisplay, 'Hours not verified');
      expect(clinic.distanceKm, 0.5);
      expect(clinic.category.displayName, 'Clinic');
    });

    test('Hospital serialization to and from Map preserves all fields', () {
      final original = Hospital(
        id: 'test-1',
        name: 'Manipal Hospital',
        category: HealthcareCategory.emergencyDepartment,
        latitude: 12.9592,
        longitude: 77.6567,
        address: 'HAL Airport Road',
        phoneNumber: '08025024444',
        emergencyServiceVerified: true,
        emergencyVerificationSource: 'osm_tag_emergency=yes',
        distanceMeters: 3400,
      );

      final map = original.toMap();
      final revived = Hospital.fromMap(map);

      expect(revived.id, original.id);
      expect(revived.name, original.name);
      expect(revived.category, original.category);
      expect(revived.emergencyServiceVerified, isTrue);
      expect(revived.phoneNumber, original.phoneNumber);
      expect(revived.distanceMeters, original.distanceMeters);
    });
  });

  group('EmergencyContact Model isPrimary Tests', () {
    test('EmergencyContact supports isPrimary flag serialization and defaults', () {
      final contact = EmergencyContact(
        id: 'c1',
        name: 'Priya Sharma',
        relationship: 'Spouse',
        phone: '+91 98765 43210',
        isPrimary: true,
      );

      expect(contact.isPrimary, isTrue);

      final map = contact.toMap();
      expect(map['isPrimary'], isTrue);

      final revived = EmergencyContact.fromMap(map);
      expect(revived.isPrimary, isTrue);
      expect(revived.displayPhone, '+91 98765 43210');
    });

    test('EmergencyContact defaults isPrimary to false when omitted', () {
      final map = {
        'id': 'c2',
        'name': 'Rahul',
        'relationship': 'Friend',
        'phone': '9876543211',
      };

      final contact = EmergencyContact.fromMap(map);
      expect(contact.isPrimary, isFalse);
    });
  });
}
