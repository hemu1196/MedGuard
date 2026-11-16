import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FallDetectionService {
  static final FallDetectionService _instance = FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  bool _isEnabled = false;
  DateTime? _lastFallAt;
  bool _isListening = false;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  final _fallStreamController = StreamController<bool>.broadcast();

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  bool get isSupportedPlatform => !kIsWeb;

  Stream<bool> get onFallDetected => _fallStreamController.stream;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('fall_detection_enabled') ?? false;
    if (_isEnabled) startListening();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (enabled && isSupportedPlatform) {
      startListening();
    } else {
      stopListening();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fall_detection_enabled', enabled);
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
            _emitFall();
          }
        },
        onError: (error) {
          _isListening = false;
          debugPrint('[FALL SENSOR ERROR] Sensor stream failed: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isListening = false;
      debugPrint('[FALL SENSOR EXCEPTION] $e');
    }
  }

  void stopListening() {
    _isListening = false;
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void _emitFall() {
    final now = DateTime.now();
    if (!_isEnabled || (_lastFallAt != null && now.difference(_lastFallAt!).inSeconds < 30)) return;
    _lastFallAt = now;
    _fallStreamController.add(true);
  }

  void simulateFallForTesting() {
    if (_isEnabled) {
      _emitFall();
    }
  }

  void dispose() {
    stopListening();
    _fallStreamController.close();
  }
}
