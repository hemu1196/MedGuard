import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/models/medicine.dart';
import 'package:med_ai/models/health_record.dart';
import 'package:med_ai/core/utils/bmi_calculator.dart';
import 'package:med_ai/repositories/medicine_repository.dart';
import 'package:med_ai/services/notification_service.dart';
import 'package:med_ai/services/in_app_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Medicine CRUD & Stable IDs', () {
    test('Medicine model serializes and deserializes canonical ID and doses', () {
      final med = Medicine(
        id: '652c78a1bc1234567890abcd',
        userId: 'user_123',
        name: 'Metformin',
        dosage: '500 mg',
        frequency: 'Twice daily',
        reminderTimes: ['08:00 AM', '08:00 PM'],
        quantityAvailable: 50,
      );

      final map = med.toMap();
      expect(map['_id'], equals('652c78a1bc1234567890abcd'));
      expect(map['times'], containsAll(['08:00 AM', '08:00 PM']));
      expect(map['remainingStock'], equals(50));

      final restored = Medicine.fromMap(map);
      expect(restored.id, equals('652c78a1bc1234567890abcd'));
      expect(restored.name, equals('Metformin'));
      expect(restored.reminderTimes.length, equals(2));
      expect(restored.quantityAvailable, equals(50));
    });

    test('MedicineRepository saves, watches, and deletes medicine with local fallback', () async {
      final repo = MedicineRepository();
      const userId = 'test_user_med_1';

      final med = Medicine(
        id: '652c78a1bc1234567890abcd',
        userId: userId,
        name: 'Amoxicillin',
        dosage: '250 mg',
        frequency: 'Once daily',
        reminderTimes: ['09:00 AM'],
      );

      final saved = await repo.saveMedicine(med);
      expect(saved, isNotNull);
      expect(saved!.name, equals('Amoxicillin'));

      final listAfterSave = await repo.getMedicines(userId: userId);
      expect(listAfterSave.length, equals(1));
      expect(listAfterSave.first.name, equals('Amoxicillin'));

      final deleteSuccess = await repo.deleteMedicine('652c78a1bc1234567890abcd', userId: userId);
      expect(deleteSuccess, isTrue);

      final listAfterDelete = await repo.getMedicines(userId: userId);
      expect(listAfterDelete, isEmpty);
    });
  });

  group('NotificationService & Stable ID Generation', () {
    test('NotificationService stable ID generation produces consistent IDs', () {
      final service = NotificationService();
      final id1 = service.generateMedicineNotifId('med_123', '08:00 AM');
      final id2 = service.generateMedicineNotifId('med_123', '08:00 AM');
      final idDiff = service.generateMedicineNotifId('med_123', '08:00 PM');

      expect(id1, equals(id2));
      expect(id1, isNot(equals(idDiff)));
      expect(id1, greaterThanOrEqualTo(100000));
      expect(id1, lessThan(500000));
    });

    test('InAppNotificationService records medicine reminders with high accuracy', () async {
      final inApp = InAppNotificationService();
      await inApp.loadNotifications();
      await inApp.clearAll();

      await inApp.addNotification(
        title: 'Medicine Reminder: Amoxicillin (250 mg)',
        body: 'Scheduled dose at 09:00 AM',
        type: NotificationType.medicine,
        targetRoute: '/medicines',
      );

      expect(inApp.unreadCount, equals(1));
      expect(inApp.items.first.title, contains('Amoxicillin'));
    });
  });

  group('Diet & Fitness BMI & Guidance Calculations', () {
    test('BmiCalculator calculates BMI accurately', () {
      final bmi = BmiCalculator.calculateBMI(heightCm: 175, weightKg: 70);
      expect(bmi, equals(22.9));

      final category = BmiCalculator.getBMICategory(bmi);
      expect(category, equals('Normal range'));
    });

    test('BmiCalculator handles underweight, overweight and obese thresholds', () {
      expect(BmiCalculator.getBMICategory(17.5), equals('Underweight'));
      expect(BmiCalculator.getBMICategory(23.0), equals('Normal range'));
      expect(BmiCalculator.getBMICategory(27.5), equals('Overweight'));
      expect(BmiCalculator.getBMICategory(32.0), equals('Obesity'));
    });
  });

  group('Health Vault Attachment & Summary Verification', () {
    test('HealthRecord detects PDF attachment vs image attachment', () {
      final pdfRecord = HealthRecord(
        id: '652c78a1bc12345678900001',
        userId: 'user_vault_1',
        title: 'Blood Panel Report.pdf',
        recordType: HealthRecordType.labReport,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
        fileUrl: 'https://medguard-backend.com/file.pdf',
      );
      expect(pdfRecord.hasFileAttachment, isTrue);
      expect(pdfRecord.isPdf, isTrue);

      final imageRecord = HealthRecord(
        id: '652c78a1bc12345678900002',
        userId: 'user_vault_1',
        title: 'X-Ray Scan.jpg',
        recordType: HealthRecordType.imaging,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
        fileUrl: 'https://medguard-backend.com/scan.jpg',
      );
      expect(imageRecord.hasFileAttachment, isTrue);
      expect(imageRecord.isPdf, isFalse);

      final noteOnlyRecord = HealthRecord(
        id: '652c78a1bc12345678900003',
        userId: 'user_vault_1',
        title: 'Doctor Advice Note',
        recordType: HealthRecordType.consultation,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
      );
      expect(noteOnlyRecord.hasFileAttachment, isFalse);
    });
  });
}
