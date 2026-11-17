import 'dart:async';
import 'package:med_ai/core/api/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/services/medicine_action_outbox.dart';
import 'package:med_ai/services/health_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient().resetForTesting();
    MedicineActionOutbox.resetForTesting();
    HealthPreferences.resetForTesting();
  });
  await testMain();
}
