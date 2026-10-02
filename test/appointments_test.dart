import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/models/appointment.dart';
import 'package:med_ai/repositories/appointment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Appointment Model & Repository Tests', () {
    test('Appointment model serializes and deserializes correctly with multi-reminders', () {
      final now = DateTime.now();
      final appt = Appointment(
        id: 'appt_1',
        userId: 'user_test_123',
        doctorName: 'Arun Kumar',
        specialization: 'Cardiologist',
        hospitalOrClinic: 'Apollo Hospital',
        appointmentDate: now.add(const Duration(days: 2)),
        phoneNumber: '+91 9876543210',
        notes: 'Follow-up ECG check',
        selectedRemindersMinutes: [1440, 60, 30, 0],
        status: 'Upcoming',
      );

      final map = appt.toMap();
      final restored = Appointment.fromMap(map);

      expect(restored.id, equals('appt_1'));
      expect(restored.userId, equals('user_test_123'));
      expect(restored.doctorName, equals('Arun Kumar'));
      expect(restored.specialization, equals('Cardiologist'));
      expect(restored.hospitalOrClinic, equals('Apollo Hospital'));
      expect(restored.selectedRemindersMinutes, containsAll([1440, 60, 30, 0]));
      expect(restored.reminderOffsets.length, equals(4));
    });

    test('AppointmentRepository starts with empty list for fresh user', () async {
      final repo = AppointmentRepository();
      final list = await repo.getAppointments(userId: 'fresh_user_456');
      expect(list, isEmpty);
    });

    test('AppointmentRepository saves, retrieves, updates status, and deletes appointment', () async {
      final repo = AppointmentRepository();
      const userId = 'user_789';

      final appt = Appointment(
        id: 'appt_100',
        userId: userId,
        doctorName: 'Sarah Jenkins',
        specialization: 'Neurologist',
        hospitalOrClinic: 'City Health Clinic',
        appointmentDate: DateTime.now().add(const Duration(days: 3)),
        status: 'Upcoming',
      );

      final saveResult = await repo.saveAppointment(userId, appt);
      expect(saveResult, isTrue);

      final retrieved = await repo.getAppointments(userId: userId);
      expect(retrieved.length, equals(1));
      expect(retrieved.first.doctorName, equals('Sarah Jenkins'));
      expect(retrieved.first.hospitalOrClinic, equals('City Health Clinic'));

      final updateResult = await repo.updateStatus(userId, 'appt_100', 'Completed');
      expect(updateResult, isTrue);

      final updatedList = await repo.getAppointments(userId: userId);
      expect(updatedList.first.status, equals('Completed'));

      final deleteResult = await repo.deleteAppointment(userId, 'appt_100');
      expect(deleteResult, isTrue);

      final finalEmpty = await repo.getAppointments(userId: userId);
      expect(finalEmpty, isEmpty);
    });
  });
}
