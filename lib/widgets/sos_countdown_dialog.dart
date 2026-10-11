import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';

class SosCountdownDialog extends StatefulWidget {
  final int totalSeconds;
  final String triggerWord;
  final VoidCallback onCountdownComplete;
  final VoidCallback onCancel;

  const SosCountdownDialog({
    super.key,
    this.totalSeconds = 5,
    this.triggerWord = 'HELP / SOS',
    required this.onCountdownComplete,
    required this.onCancel,
  });

  @override
  State<SosCountdownDialog> createState() => _SosCountdownDialogState();
}

class _SosCountdownDialogState extends State<SosCountdownDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.totalSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _triggerHaptic();
    _startCountdown();
  }

  void _triggerHaptic() {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Haptics/sound may be unavailable on web or some emulators
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      _triggerHaptic();

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _completed = true;
        Navigator.of(context).pop(true);
        widget.onCountdownComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    _timer?.cancel();
    _completed = true;
    Navigator.of(context).pop(false);
    widget.onCancel();
  }

  void _handleSendNow() {
    _timer?.cancel();
    _completed = true;
    Navigator.of(context).pop(true);
    widget.onCountdownComplete();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / widget.totalSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_completed) {
          _handleCancel();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing Emergency Warning Ring
              ScaleTransition(
                scale: _pulseAnimation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.red.shade100,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentRed),
                      ),
                    ),
                    Container(
                      height: 92,
                      width: 92,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent,
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$_remainingSeconds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'VOICE SOS DETECTED',
                style: TextStyle(
                  color: AppTheme.accentRed,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              // Keyword details
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Keyword Heard: "${widget.triggerWord}"',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Message
              Text(
                'MEDGUARD will dispatch an emergency SOS alert with live GPS coordinates in $_remainingSeconds second${_remainingSeconds == 1 ? '' : 's'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Cancel SOS Button (Prominent & Clear)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _handleCancel,
                  icon: const Icon(Icons.close_rounded, size: 24, color: AppTheme.accentRed),
                  label: const Text(
                    'CANCEL SOS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.accentRed,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentRed, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Immediate Trigger Button (Bypass countdown)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _handleSendNow,
                  icon: const Icon(Icons.flash_on, size: 18, color: AppTheme.accentRed),
                  label: const Text(
                    'SEND IMMEDIATELY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentRed,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
