import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:med_ai/core/database/database_helper.dart';
import 'package:med_ai/models/water_intake.dart';
import 'package:med_ai/repositories/water_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.deleteTodayWaterIntake('test_user_1');
    await DatabaseHelper.instance.deleteTodayWaterIntake('test_user_2');
  });

  group('WaterIntake Model & Progress Unit Tests', () {
    test('DailyWaterIntake progress ratio clamps between 0.0 and 1.0', () {
      final intakeLow = DailyWaterIntake(userId: 'u1', currentMl: 500, targetMl: 2000);
      expect(intakeLow.progressRatio, equals(0.25));

      final intakeFull = DailyWaterIntake(userId: 'u1', currentMl: 2000, targetMl: 2000);
      expect(intakeFull.progressRatio, equals(1.0));

      final intakeOver = DailyWaterIntake(userId: 'u1', currentMl: 3000, targetMl: 2000);
      expect(intakeOver.progressRatio, equals(1.0));
    });

    test('WaterIntake serialization toMap and fromMap works correctly', () {
      final now = DateTime.now();
      final log = WaterIntake(
        id: '123',
        userId: 'userA',
        amountMl: 500,
        timestamp: now,
      );

      final map = log.toMap();
      final restored = WaterIntake.fromMap(map);

      expect(restored.id, equals('123'));
      expect(restored.userId, equals('userA'));
      expect(restored.amountMl, equals(500));
      expect(restored.timestamp.year, equals(now.year));
      expect(restored.timestamp.day, equals(now.day));
    });
  });

  group('WaterRepository Persistence & State Unit Tests', () {
    final repo = WaterRepository();

    test('Starts at 0 ml for new user', () async {
      final intake = await repo.getTodayWaterIntake(userId: 'test_user_1');
      expect(intake.currentMl, equals(0));
      expect(intake.logs, isEmpty);
      expect(intake.targetMl, equals(2000));
    });

    test('Adding preset volumes updates total, progress, and history immediately', () async {
      final u1 = 'test_user_1';

      var data = await repo.addWater(200, userId: u1);
      expect(data.currentMl, equals(200));
      expect(data.logs.length, equals(1));
      expect(data.logs.first.amountMl, equals(200));

      data = await repo.addWater(500, userId: u1);
      expect(data.currentMl, equals(700));
      expect(data.logs.length, equals(2));

      data = await repo.addWater(300, userId: u1);
      expect(data.currentMl, equals(1000));
      expect(data.logs.length, equals(3));
    });

    test('User isolation: user_1 records do not appear for user_2', () async {
      final u1 = 'test_user_1';
      final u2 = 'test_user_2';

      await repo.addWater(500, userId: u1);
      final intakeU1 = await repo.getTodayWaterIntake(userId: u1);
      final intakeU2 = await repo.getTodayWaterIntake(userId: u2);

      expect(intakeU1.currentMl, equals(500));
      expect(intakeU2.currentMl, equals(0));
      expect(intakeU2.logs, isEmpty);
    });

    test('Reset today clears today logs and resets total to 0 ml', () async {
      final u1 = 'test_user_1';

      await repo.addWater(400, userId: u1);
      await repo.addWater(600, userId: u1);

      var data = await repo.getTodayWaterIntake(userId: u1);
      expect(data.currentMl, equals(1000));

      data = await repo.resetWater(userId: u1);
      expect(data.currentMl, equals(0));
      expect(data.logs, isEmpty);
    });
  });
}
