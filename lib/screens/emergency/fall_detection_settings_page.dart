import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/fall_detection_service.dart';
import '../../widgets/app_header.dart';

class FallDetectionSettingsPage extends StatefulWidget {
  const FallDetectionSettingsPage({super.key});

  @override
  State<FallDetectionSettingsPage> createState() =>
      _FallDetectionSettingsPageState();
}

class _FallDetectionSettingsPageState extends State<FallDetectionSettingsPage> {
  final FallDetectionService _fallService = FallDetectionService();
  late bool _isEnabled;
  Timer? _countdownTimer;
  int _secondsRemaining = 10;
  bool _isCountdownActive = false;

  @override
  void initState() {
    super.initState();
    _isEnabled = _fallService.isEnabled;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _triggerSimulatedFall() {
    setState(() {
      _secondsRemaining = 10;
      _isCountdownActive = true;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _countdownTimer?.cancel();
          _isCountdownActive = false;
          // Trigger emergency SOS
          Navigator.of(context).pushNamed(AppRoutes.emergency);
        }
      });
    });
  }

  void _cancelFalseAlarm() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _secondsRemaining = 10;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fall Alarm Cancelled. You are marked safe.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Fall Detection Settings',
        subtitle: 'Sudden motion detection & emergency countdown',
        showBack: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Web Fallback Notice if running on Web
              if (kIsWeb) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.devices, color: AppColors.secondary, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fall Detection is available on supported mobile devices with motion sensors (Accelerometer & Gyroscope).',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Enable Toggle Switch
              Card(
                child: SwitchListTile(
                  title: const Text(
                    'Enable Fall Detection',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Automatically start emergency countdown if a sudden fall is detected',
                  ),
                  secondary: const Icon(
                    Icons.sensor_occupied,
                    color: AppColors.emergency,
                  ),
                  value: _isEnabled,
                  onChanged: (val) {
                    setState(() {
                      _isEnabled = val;
                      _fallService.setEnabled(val);
                    });
                  },
                  activeThumbColor: AppColors.emergency,
                ),
              ),
              const SizedBox(height: 20),

              // Countdown Alert Simulation Card
              if (_isCountdownActive) ...[
                Card(
                  color: const Color(0xFFFEF2F2),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 48,
                          color: AppColors.emergency,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'POSSIBLE FALL DETECTED!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emergency,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Triggering Emergency SOS in $_secondsRemaining seconds...',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            onPressed: _cancelFalseAlarm,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('I AM OK — CANCEL ALARM'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Info & Test Simulation Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How Fall Detection Works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Divider(height: 20),
                      const Text(
                        '1. Accelerometer sensors detect rapid impact or freefall.\n'
                        '2. A 10-second warning countdown begins with audio alert.\n'
                        '3. If not cancelled, your emergency contacts and helpline SOS are notified immediately.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isEnabled ? _triggerSimulatedFall : null,
                          icon: const Icon(
                            Icons.play_arrow,
                            color: AppColors.emergency,
                          ),
                          label: const Text(
                            'Simulate Fall Test (10s Countdown)',
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.emergency),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: Fall detection is an informational emergency assistance feature and does not guarantee 100% detection of all falls.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
