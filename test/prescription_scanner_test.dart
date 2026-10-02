import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/models/medicine.dart';
import 'package:med_ai/models/prescription.dart';
import 'package:med_ai/services/prescription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Prescription Model & Service Unit Tests', () {
    test('Prescription serialization and deserialization works correctly', () {
      final now = DateTime.now();
      final rx = Prescription(
        id: 'rx_001',
        title: 'Dr. Smith Consultation',
        doctorName: 'Dr. John Smith',
        date: now,
        medicines: [
          Medicine(
            id: 'm1',
            name: 'Ibuprofen 400mg',
            dosage: '1 tablet',
            frequency: 'Daily',
            reminderTimes: const ['08:00 AM'],
          ),
        ],
        notes: 'Take after food',
      );

      final map = rx.toMap();
      final restored = Prescription.fromMap(map);

      expect(restored.id, equals('rx_001'));
      expect(restored.title, equals('Dr. Smith Consultation'));
      expect(restored.doctorName, equals('Dr. John Smith'));
      expect(restored.medicines.length, equals(1));
      expect(restored.medicines.first.name, equals('Ibuprofen 400mg'));
    });

    test('PrescriptionService starts with an empty list for fresh user', () async {
      final service = PrescriptionService();
      final prescriptions = await service.getPrescriptions();
      expect(prescriptions, isEmpty);
    });

    test('PrescriptionService saves and retrieves user prescriptions accurately', () async {
      final service = PrescriptionService();
      final rx = Prescription(
        id: 'rx_100',
        title: 'Cardiology Script',
        doctorName: 'Dr. Alice Vance',
        date: DateTime.now(),
        medicines: [
          Medicine(
            id: 'm10',
            name: 'Atorvastatin 10mg',
            dosage: '1 tablet nightly',
            frequency: 'Daily',
            reminderTimes: const ['09:00 PM'],
          ),
        ],
      );

      final saved = await service.savePrescription(rx);
      expect(saved, isTrue);

      final list = await service.getPrescriptions();
      expect(list.length, equals(1));
      expect(list.first.doctorName, equals('Dr. Alice Vance'));
      expect(list.first.medicines.first.name, equals('Atorvastatin 10mg'));
    });
  });
}
