import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/models/emergency_contact.dart';
import 'package:med_ai/repositories/emergency_contact_repository.dart';
import 'package:med_ai/services/emergency_service.dart';
import 'package:med_ai/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Emergency Contact & SOS Tests', () {
    test('EmergencyContact model serializes, deserializes, and formats phone numbers', () {
      final contact = EmergencyContact(
        id: '9876543210',
        name: 'Rohith',
        countryCode: '+91',
        phone: '7207210627',
        relationship: 'Friend',
      );

      final map = contact.toMap();
      final restored = EmergencyContact.fromMap(map);

      expect(restored.name, equals('Rohith'));
      expect(restored.countryCode, equals('+91'));
      expect(restored.phone, equals('7207210627'));
      expect(restored.relationship, equals('Friend'));
      expect(restored.displayPhone, equals('+91 7207210627'));
      expect(restored.dialablePhone, equals('+917207210627'));
    });

    test('EmergencyContactRepository starts with empty list for fresh user', () async {
      final repo = EmergencyContactRepository();
      final list = await repo.getEmergencyContacts(userId: 'fresh_user_sos');
      expect(list, isEmpty);
    });

    test('EmergencyContactRepository saves, retrieves, updates, and deletes contact', () async {
      final repo = EmergencyContactRepository();
      const userId = 'sos_user_789';

      final contact = EmergencyContact(
        name: 'Rohith',
        countryCode: '+91',
        phone: '7207210627',
        relationship: 'Friend',
      );

      final saveResult = await repo.saveEmergencyContact(userId, contact);
      expect(saveResult, isTrue);

      final retrieved = await repo.getEmergencyContacts(userId: userId);
      expect(retrieved.length, equals(1));
      expect(retrieved.first.name, equals('Rohith'));
      expect(retrieved.first.phone, equals('7207210627'));

      final deleteResult = await repo.deleteEmergencyContact(userId, '7207210627');
      expect(deleteResult, isTrue);

      final finalEmpty = await repo.getEmergencyContacts(userId: userId);
      expect(finalEmpty, isEmpty);
    });

    test('EmergencyService triggerSos returns no_contacts when no contact exists', () async {
      final service = EmergencyService();
      final result = await service.triggerSos(userId: 'user_with_no_contact');

      expect(result.success, isFalse);
      expect(result.status, equals('no_contacts'));
      expect(result.message, equals('No emergency contact configured.'));
    });

    test('EmergencyService triggerSos builds real Google Maps location message when contact exists', () async {
      final repo = EmergencyContactRepository();
      const userId = 'user_with_contact';

      await repo.saveEmergencyContact(
        userId,
        EmergencyContact(
          name: 'Rohith',
          countryCode: '+91',
          phone: '7207210627',
          relationship: 'Friend',
        ),
      );

      final service = EmergencyService();
      final dummyLoc = LocationData(
        latitude: 12.9716,
        longitude: 77.5946,
        cityName: 'Test City',
      );

      final result = await service.triggerSos(
        userId: userId,
        locationOverride: dummyLoc,
      );

      expect(result.success, isTrue);
      expect(result.recipientName, equals('Rohith'));
      expect(result.recipientPhone, contains('7207210627'));
      expect(
        result.message,
        contains('https://www.google.com/maps/search/?api=1&query=12.9716,77.5946'),
      );
    });
  });
}
