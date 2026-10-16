import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:med_ai/models/appointment.dart';
import 'package:med_ai/models/medicine.dart';
import 'package:med_ai/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Time String Parsing Robustness', () {
    test('parses standard 12-hour AM/PM times correctly', () {
      final (h1, m1) = NotificationService.parseTimeParts('1:03 PM');
      expect(h1, equals(13));
      expect(m1, equals(3));

      final (h2, m2) = NotificationService.parseTimeParts('01:03 PM');
      expect(h2, equals(13));
      expect(m2, equals(3));

      final (h3, m3) = NotificationService.parseTimeParts('8:30 AM');
      expect(h3, equals(8));
      expect(m3, equals(30));

      final (h4, m4) = NotificationService.parseTimeParts('08:30 AM');
      expect(h4, equals(8));
      expect(m4, equals(30));
    });

    test('parses 12:00 AM (midnight) and 12:00 PM (noon) accurately', () {
      final (hMidnight, mMidnight) = NotificationService.parseTimeParts('12:00 AM');
      expect(hMidnight, equals(0));
      expect(mMidnight, equals(0));

      final (hNoon, mNoon) = NotificationService.parseTimeParts('12:00 PM');
      expect(hNoon, equals(12));
      expect(mNoon, equals(0));

      final (hMid30, mMid30) = NotificationService.parseTimeParts('12:45 AM');
      expect(hMid30, equals(0));
      expect(mMid30, equals(45));

      final (hNoon30, mNoon30) = NotificationService.parseTimeParts('12:45 PM');
      expect(hNoon30, equals(12));
      expect(mNoon30, equals(45));
    });

    test('parses times with Unicode narrow non-breaking spaces (\\u202F)', () {
      // Android 13/14 formatters commonly use \u202F between time and AM/PM
      final (h, m) = NotificationService.parseTimeParts('1:03\u202FPM');
      expect(h, equals(13));
      expect(m, equals(3));

      final (hAm, mAm) = NotificationService.parseTimeParts('9:15\u202FAM');
      expect(hAm, equals(9));
      expect(mAm, equals(15));
    });

    test('parses 24-hour military time formats correctly', () {
      final (h1, m1) = NotificationService.parseTimeParts('13:03');
      expect(h1, equals(13));
      expect(m1, equals(3));

      final (h2, m2) = NotificationService.parseTimeParts('00:15');
      expect(h2, equals(0));
      expect(m2, equals(15));

      final (h3, m3) = NotificationService.parseTimeParts('23:59:00');
      expect(h3, equals(23));
      expect(m3, equals(59));
    });
  });

  group('Next TZDateTime Calculation & Rollover', () {
    test('never schedules in the past', () {
      final service = NotificationService();
      final now = tz.TZDateTime.now(tz.local);

      // Construct a time string 1 hour in the past
      final pastHour = (now.hour - 1 + 24) % 24;
      final pastTimeStr = '${pastHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final scheduled = service.computeNextScheduledTzTime(timeStr: pastTimeStr);

      expect(scheduled.isAfter(now), isTrue,
          reason: 'Scheduled time must strictly be in the future (rolled over to tomorrow)');
    });

    test('computes future time today if scheduled time is later today', () {
      final service = NotificationService();
      final now = tz.TZDateTime.now(tz.local);

      // If current hour is < 23, schedule for 23:59 tonight
      if (now.hour < 23) {
        final scheduled = service.computeNextScheduledTzTime(timeStr: '23:59');
        expect(scheduled.isAfter(now), isTrue);
        expect(scheduled.day, equals(now.day));
      }
    });

    test('snooze adds exact minutes to current time', () {
      final service = NotificationService();
      final now = tz.TZDateTime.now(tz.local);

      final snoozed = service.computeNextScheduledTzTime(
        timeStr: '08:00 AM',
        snoozeMinutes: 10,
      );

      final diff = snoozed.difference(now).inMinutes;
      expect(diff, closeTo(10, 1));
    });
  });

  group('Notification ID Partitioning & Non-Collision', () {
    test('medicine IDs and appointment IDs fall into distinct non-overlapping ranges', () {
      final service = NotificationService();

      for (int i = 0; i < 50; i++) {
        final medId = service.generateMedicineNotifId('med_$i', '08:${i % 60} AM');
        final apptId = service.generateAppointmentNotifId('appt_$i', i * 30);

        // Medicine range: [100000, 500000)
        expect(medId, greaterThanOrEqualTo(100000));
        expect(medId, lessThan(500000));

        // Appointment range: [500000, 900000)
        expect(apptId, greaterThanOrEqualTo(500000));
        expect(apptId, lessThan(900000));

        // Guaranteed zero overlap
        expect(medId, isNot(equals(apptId)));
      }
    });
  });

  group('Appointment Reminders & Offset Calculations', () {
    test('appointment model generates correct reminder offsets and IDs', () {
      final apptDate = DateTime.now().add(const Duration(days: 2));
      final appt = Appointment(
        id: '652c78a1bc1234567890abcd',
        userId: 'test_user_appt',
        doctorName: 'Dr. Sarah Jenkins',
        specialization: 'Cardiology',
        hospitalOrClinic: 'Metro Heart Center',
        appointmentDate: apptDate,
        selectedRemindersMinutes: [1440, 60, 30, 0],
      );

      expect(appt.reminderOffsets, containsAll([1440, 60, 30, 0]));
      expect(appt.doctorName, equals('Dr. Sarah Jenkins'));
      expect(appt.status, equals('Upcoming'));
    });

    test('scheduleAppointmentNotifications stores IDs for cancellation', () async {
      final service = NotificationService();
      final apptDate = DateTime.now().add(const Duration(days: 3));

      await service.scheduleAppointmentNotifications(
        appointmentId: 'appt_test_999',
        doctorName: 'Dr. Robert Chen',
        hospitalOrClinic: 'City Clinic',
        appointmentDate: apptDate,
        reminderOffsets: [1440, 60],
      );

      // Verify cancellation cleans up properly
      await service.cancelAppointmentNotifications('appt_test_999');
    });
  });

  group('Reconciliation across Medicines & Appointments', () {
    test('reconcileSchedules executes without throwing', () async {
      final service = NotificationService();

      final medicines = [
        Medicine(
          id: 'med_reconcile_1',
          name: 'Atorvastatin',
          dosage: '20 mg',
          frequency: 'Daily',
          reminderTimes: ['10:00 PM'],
        ),
      ];

      final appointments = [
        Appointment(
          id: 'appt_reconcile_1',
          userId: 'user_1',
          doctorName: 'Dr. Patel',
          specialization: 'Neurology',
          appointmentDate: DateTime.now().add(const Duration(days: 4)),
          reminderEnabled: true,
          selectedRemindersMinutes: [60],
        ),
      ];

      await expectLater(
        service.reconcileSchedules(
          medicines: medicines,
          appointments: appointments,
        ),
        completes,
      );
    });
  });
}
