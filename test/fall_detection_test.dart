import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/services/fall_detection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fall detection requires opt-in, persists it, and debounces duplicate events', () async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in ['dev.fluttercommunity.plus/sensors/method', 'dev.fluttercommunity.plus/sensors/user_accel']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    final service = FallDetectionService();
    await service.initialize();
    expect(service.isEnabled, isFalse);
    final events = <bool>[];
    final subscription = service.onFallDetected.listen(events.add);
    service.simulateFallForTesting();
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    await service.setEnabled(true);
    expect((await SharedPreferences.getInstance()).getBool('fall_detection_enabled'), isTrue);
    service.simulateFallForTesting();
    service.simulateFallForTesting();
    await Future<void>.delayed(Duration.zero);
    expect(events, [true]);

    await service.setEnabled(false);
    service.simulateFallForTesting();
    await Future<void>.delayed(Duration.zero);
    expect(events, [true]);
    expect((await SharedPreferences.getInstance()).getBool('fall_detection_enabled'), isFalse);
    expect(service.isListening, isFalse);
    await subscription.cancel();
  });
}
