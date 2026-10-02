import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class FallDetectionService {
  static final FallDetectionService _instance = FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  bool _isEnabled = true;
  bool _isListening = false;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  final _fallStreamController = StreamController<bool>.broadcast();

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  bool get isSupportedPlatform => !kIsWeb;

  Stream<bool> get onFallDetected => _fallStreamController.stream;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled && isSupportedPlatform) {
      startListening();
    } else {
      stopListening();
    }
  }

  void startListening() {
    if (!isSupportedPlatform || !_isEnabled || _isListening) return;
    _isListening = true;

    try {
      _accelSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          final acceleration = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          // Threshold of 28 m/s^2 indicates a severe impact / fall event
          if (acceleration > 28.0) {
            debugPrint('[FALL SENSOR] Sudden impact detected: $acceleration m/s^2');
            _fallStreamController.add(true);
          }
        },
        onError: (error) {
          debugPrint('[FALL SENSOR ERROR] Sensor stream failed: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[FALL SENSOR EXCEPTION] $e');
    }
  }

  void stopListening() {
    _isListening = false;
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void simulateFallForTesting() {
    if (_isEnabled) {
      _fallStreamController.add(true);
    }
  }

  void dispose() {
    stopListening();
    _fallStreamController.close();
  }
}
