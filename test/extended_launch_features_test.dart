import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/models/medicine.dart';
import 'package:med_ai/services/medicine_schedule.dart';
import 'package:med_ai/services/encrypted_emergency_card.dart';
import 'package:med_ai/services/health_preferences.dart';
import 'package:med_ai/services/private_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() => data.initializeTimeZones());
  Medicine medicine({
    String frequency = 'Daily',
    List<int> days = const [],
    DateTime? start,
    DateTime? end,
    List<String> times = const ['08:00'],
  }) => Medicine(
    id: 'test',
    name: 'Fixture',
    dosage: '1 unit',
    frequency: frequency,
    reminderTimes: times,
    weekdays: days,
    startDate: start,
    endDate: end,
  );
  test('as-needed medicine generates no scheduled or missed occurrences', () {
    expect(
      MedicineSchedule.upcoming(
        medicine(frequency: 'As Needed'),
        tz.UTC,
        DateTime.utc(2026, 11, 17),
      ),
      isEmpty,
    );
  });
  test('specific weekdays and end dates bound actual occurrences', () {
    final doses = MedicineSchedule.upcoming(
      medicine(
        frequency: 'Specific Days',
        days: [DateTime.monday],
        start: DateTime(2026, 11, 16),
        end: DateTime(2026, 11, 30),
      ),
      tz.UTC,
      DateTime.utc(2026, 11, 17),
    );
    expect(doses.map((d) => d.instant.day).toList(), [23, 30]);
    expect(doses.every((d) => d.instant.weekday == DateTime.monday), isTrue);
  });
  test('once schedule does not repeat after its configured date', () {
    expect(
      MedicineSchedule.upcoming(
        medicine(frequency: 'Once', start: DateTime(2026, 11, 16)),
        tz.UTC,
        DateTime.utc(2026, 11, 17),
      ),
      isEmpty,
    );
  });
  test(
    'DST missing local time is skipped and normal wall times remain local',
    () {
      final zone = tz.getLocation('America/New_York');
      final doses = MedicineSchedule.upcoming(
        medicine(times: ['02:30']),
        zone,
        DateTime.utc(2026, 3, 7),
        horizonDays: 4,
      );
      expect(
        doses.any((d) => d.instant.month == 3 && d.instant.day == 8),
        isFalse,
      );
      expect(
        doses.every((d) => d.instant.hour == 2 && d.instant.minute == 30),
        isTrue,
      );
    },
  );
  test('duplicate wall times create one dose per occurrence', () {
    final doses = MedicineSchedule.upcoming(
      medicine(times: ['08:00', '8:00 AM']),
      tz.UTC,
      DateTime.utc(2026, 11, 17),
      horizonDays: 1,
    );
    expect(doses.length, 1);
  });
  test(
    'encrypted portable cards reject wrong passwords and tampering',
    () async {
      const password = 'synthetic-test-password';
      final card = {
        'userName': 'Test patient',
        'bloodGroup': 'Unknown',
        'savedAt': '2026-11-17',
      };
      final encrypted = await EncryptedEmergencyCard.encrypt(card, password);
      expect(await EncryptedEmergencyCard.decrypt(encrypted, password), card);
      await expectLater(
        EncryptedEmergencyCard.decrypt(encrypted, 'incorrect-password'),
        throwsA(anything),
      );
      final tampered = List<int>.from(encrypted);
      tampered[tampered.length ~/ 2] ^= 1;
      await expectLater(
        EncryptedEmergencyCard.decrypt(tampered, password),
        throwsA(anything),
      );
    },
  );
  test(
    'health cache migrates out of ordinary preferences and clears on logout',
    () async {
      SharedPreferences.setMockInitialValues({
        'user_medicines_list_test': ['private fixture'],
        'theme': 'light',
      });
      final cache = await HealthPreferences.getInstance();
      expect(cache.getStringList('user_medicines_list_test'), [
        'private fixture',
      ]);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'user_medicines_list_test',
        ),
        isNull,
      );
      expect(
        (await SharedPreferences.getInstance()).getString('theme'),
        'light',
      );
      await PrivateLocalStore.clear();
      expect(
        (await HealthPreferences.getInstance()).getStringList(
          'user_medicines_list_test',
        ),
        isNull,
      );
    },
  );
}
