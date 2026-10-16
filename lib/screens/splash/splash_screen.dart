import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/routes.dart';
import '../../models/appointment.dart';
import '../../models/medicine.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/medicine_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/in_app_notification_service.dart';
import '../../services/notification_service.dart';
import '../../services/onboarding_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _logoFadeAnim;
  late Animation<double> _logoScaleAnim;
  late Animation<double> _titleFadeAnim;
  late Animation<Offset> _titleSlideAnim;
  late Animation<double> _taglineFadeAnim;
  late Animation<double> _ecgAnim;

  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Setup animations matching Part 2 specifications
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _logoScaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _titleFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
    );

    _titleSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
    );

    _ecgAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.linear),
      ),
    );

    _animController.forward();
    _initializeAppAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeAppAndNavigate() async {
    final startTime = DateTime.now();

    // 1. Initialize core background services
    try {
      await Future.wait([
        NotificationService().init(),
        InAppNotificationService().loadNotifications(),
      ]);
    } catch (e) {
      debugPrint('[SPLASH] Service init notice: $e');
    }

    // 2. Read onboarding and authentication states concurrently
    bool onboardingCompleted = false;
    bool isAuth = false;
    bool hasProfile = false;

    try {
      onboardingCompleted = await OnboardingService.isOnboardingCompleted();
      isAuth = await _authRepository.isAuthenticated();

      if (isAuth) {
        final userId = await _authRepository.getCurrentUserId();
        if (userId.isNotEmpty) {
          hasProfile = await _profileRepository.profileExists(userId);
          unawaited(_reconcileSchedules(userId));
        }
      }
    } catch (e) {
      debugPrint('[SPLASH] Auth/Profile resolution note: $e');
    }

    // 3. Ensure a minimum brief presentation (~1500ms) for smooth entrance
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    const minSplashDurationMs = 1500;
    if (elapsed < minSplashDurationMs) {
      await Future.delayed(
        Duration(milliseconds: minSplashDurationMs - elapsed),
      );
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    // 4. Resolve destination according to Part 6 Flow Diagram
    if (!onboardingCompleted) {
      // First Launch / Onboarding Not Completed -> Onboarding 1
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else if (isAuth) {
      // Returning User / Valid Session -> Dashboard (or profile setup if incomplete)
      if (hasProfile) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } else {
      // Returning User / No Valid Session or Expired -> Login Screen
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<void> _reconcileSchedules(String userId) async {
    try {
      final results = await Future.wait([
        MedicineRepository().getMedicines(userId: userId),
        AppointmentRepository().getAppointments(userId: userId),
      ]);
      final meds = results[0] as List<Medicine>;
      final appts = results[1] as List<Appointment>;
      await NotificationService().reconcileSchedules(
        medicines: meds,
        appointments: appts,
      );
    } catch (e) {
      debugPrint('[SPLASH] Schedule reconciliation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF0FAF8),
                Color(0xFFE4F7F5),
                Color(0xFFD3F2EE),
              ],
              stops: [0.0, 0.45, 0.8, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Subtle background curves / decorative circular blobs
              Positioned(
                top: -60,
                right: -50,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF009E8F).withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF087F7A).withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Center Branding
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Logo
                    ScaleTransition(
                      scale: _logoScaleAnim,
                      child: FadeTransition(
                        opacity: _logoFadeAnim,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF009E8F).withValues(alpha: 0.18),
                                blurRadius: 32,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/medguard_logo.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                color: const Color(0xFF009E8F),
                                child: const Icon(
                                  Icons.health_and_safety_rounded,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App Title
                    SlideTransition(
                      position: _titleSlideAnim,
                      child: FadeTransition(
                        opacity: _titleFadeAnim,
                        child: const Text(
                          'MEDGUARD',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: Color(0xFF087F7A),
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tagline
                    FadeTransition(
                      opacity: _taglineFadeAnim,
                      child: const Text(
                        'Your Health. Our Priority.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Color(0xFF12254A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Section: Animated ECG line + Bottom text
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Faint Teal ECG / Heartbeat Line
                    AnimatedBuilder(
                      animation: _ecgAnim,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(double.infinity, 36),
                          painter: EcgPulsePainter(
                            progress: _ecgAnim.value,
                            color: const Color(0xFF009E8F).withValues(alpha: 0.4),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Bottom Tagline
                    const Text(
                      'Better Health\nBrighter Tomorrow',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF087F7A),
                        height: 1.35,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws an elegant ECG heartbeat wave
class EcgPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  EcgPulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final midY = size.height / 2;
    final w = size.width;

    // Baseline leading to heartbeat peak
    path.moveTo(0, midY);
    path.lineTo(w * 0.32, midY);

    // P-wave
    path.quadraticBezierTo(w * 0.35, midY - 4, w * 0.38, midY);

    // QRS complex
    path.lineTo(w * 0.42, midY);
    path.lineTo(w * 0.44, midY + 5); // Q
    path.lineTo(w * 0.47, midY - 20); // R peak
    path.lineTo(w * 0.50, midY + 14); // S
    path.lineTo(w * 0.53, midY);

    // T-wave
    path.quadraticBezierTo(w * 0.58, midY - 8, w * 0.63, midY);

    // Trailing baseline
    path.lineTo(w, midY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EcgPulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
