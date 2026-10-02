import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/models/health_record.dart';
import 'package:med_ai/repositories/health_record_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HealthRecord Model & Repository Unit Tests', () {
    test('HealthRecord serialization toMap and fromMap works accurately', () {
      final now = DateTime.now();
      final record = HealthRecord(
        id: 'rec_100',
        userId: 'user_vault_1',
        recordType: HealthRecordType.labReport,
        title: 'Complete Blood Count (CBC)',
        description: 'Hemoglobin and WBC normal',
        createdAt: now,
        updatedAt: now,
        documentDate: now,
        doctorName: 'Dr. John Doe',
        hospitalName: 'City Lab',
      );

      final map = record.toMap();
      final restored = HealthRecord.fromMap(map);

      expect(restored.id, equals('rec_100'));
      expect(restored.userId, equals('user_vault_1'));
      expect(restored.recordType, equals(HealthRecordType.labReport));
      expect(restored.title, equals('Complete Blood Count (CBC)'));
      expect(restored.typeDisplayName, contains('Lab Report'));
      expect(restored.doctorName, equals('Dr. John Doe'));
    });

    test('Fresh user starts with empty Health Vault', () async {
      final repo = HealthRecordRepository();
      final records = await repo.getRecords(userId: 'fresh_user_99');
      expect(records, isEmpty);
    });

    test('Saving a health record stores it under the current userId', () async {
      final repo = HealthRecordRepository();
      final u1 = 'user_vault_1';
      final u2 = 'user_vault_2';

      final record = HealthRecord(
        id: 'rec_200',
        userId: u1,
        recordType: HealthRecordType.imaging,
        title: 'Chest X-Ray Scan',
        description: 'Clear lung fields',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
      );

      final saved = await repo.saveRecord(record);
      expect(saved, isTrue);

      final u1Records = await repo.getRecords(userId: u1);
      final u2Records = await repo.getRecords(userId: u2);

      expect(u1Records.length, equals(1));
      expect(u1Records.first.title, equals('Chest X-Ray Scan'));
      expect(u2Records, isEmpty); // User isolation check
    });

    test('Editing an existing health record updates it cleanly', () async {
      final repo = HealthRecordRepository();
      final u1 = 'user_vault_1';

      final original = HealthRecord(
        id: 'rec_300',
        userId: u1,
        recordType: HealthRecordType.vaccination,
        title: 'Flu Vaccine',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
      );

      await repo.saveRecord(original);

      final updated = HealthRecord(
        id: 'rec_300',
        userId: u1,
        recordType: HealthRecordType.vaccination,
        title: 'Annual Influenza Vaccine 2026',
        description: 'Administered in left arm',
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
        documentDate: original.documentDate,
      );

      await repo.saveRecord(updated);

      final records = await repo.getRecords(userId: u1);
      expect(records.length, equals(1));
      expect(records.first.title, equals('Annual Influenza Vaccine 2026'));
      expect(records.first.description, equals('Administered in left arm'));
    });

    test('Deleting a health record removes it completely', () async {
      final repo = HealthRecordRepository();
      final u1 = 'user_vault_1';

      final record = HealthRecord(
        id: 'rec_400',
        userId: u1,
        recordType: HealthRecordType.consultation,
        title: 'General Consultation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
      );

      await repo.saveRecord(record);
      expect((await repo.getRecords(userId: u1)).length, equals(1));

      final deleted = await repo.deleteRecord('rec_400', userId: u1);
      expect(deleted, isTrue);

      final remaining = await repo.getRecords(userId: u1);
      expect(remaining, isEmpty);
    });
  });
}
