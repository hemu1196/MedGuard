import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/routes.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/onboarding_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  int _currentPage = 0;
  bool _isNavigating = false;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Your Personal\nHealth Assistant',
      'subtitle':
          'Manage your health, medicines and emergencies in one place.',
      'image': 'assets/images/onboarding_1_doctor.jpg',
      'fallbackIcon': 'doctor',
    },
    {
      'title': 'Smarter Care\nEveryday',
      'subtitle':
          'Get AI-powered insights, medicine reminders and personalized recommendations.',
      'image': 'assets/images/onboarding_2_care.jpg',
      'fallbackIcon': 'phone',
    },
    {
      'title': 'Stay Safe\nAlways',
      'subtitle':
          'Quick emergency access, nearby hospitals and real-time assistance when you need it.',
      'image': 'assets/images/onboarding_3_safety.jpg',
      'fallbackIcon': 'sos',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      // 1. Persist onboarding completion in local storage
      await OnboardingService.setOnboardingCompleted();

      // 2. Check if user has an existing active session
      final isAuth = await _authRepository.isAuthenticated();
      bool hasProfile = false;
      if (isAuth) {
        final userId = await _authRepository.getCurrentUserId();
        if (userId.isNotEmpty) {
          hasProfile = await _profileRepository.profileExists(userId);
        }
      }

      if (!mounted) return;

      // 3. Navigate accordingly
      if (isAuth) {
        if (hasProfile) {
          Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
        }
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      debugPrint('[ONBOARDING] Complete error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
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
        backgroundColor: const Color(0xFFF4FBFA),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // Top Navigation Bar (Back + Skip)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Arrow
                        _currentPage > 0
                            ? IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF12254A),
                                  size: 20,
                                ),
                                onPressed: _onBack,
                              )
                            : const SizedBox(width: 48, height: 48),

                        // Skip Action
                        TextButton(
                          onPressed: _isNavigating ? null : _completeOnboarding,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page Content Slider
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (idx) {
                        setState(() => _currentPage = idx);
                      },
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Heading
                              Text(
                                page['title']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF12254A),
                                  height: 1.25,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Subtitle
                              Text(
                                page['subtitle']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.normal,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Central Illustration with Soft Shadow
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 12.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF009E8F)
                                            .withValues(alpha: 0.08),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: Image.asset(
                                      page['image']!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (ctx, err, stack) =>
                                          _buildFallbackIllustration(
                                              page['fallbackIcon']!),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Controls (Dots & Action Button)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28.0, 10.0, 28.0, 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pagination Indicator Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pages.length, (index) {
                            final isActive = _currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              width: isActive ? 22.0 : 8.0,
                              height: 8.0,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF009E8F)
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // Action Button (Next -> or Get Started)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isNavigating ? null : _onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009E8F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                              shadowColor:
                                  const Color(0xFF009E8F).withValues(alpha: 0.35),
                            ),
                            child: _isNavigating
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentPage == _pages.length - 1
                                            ? 'Get Started'
                                            : 'Next',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      if (_currentPage < _pages.length - 1) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIllustration(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'doctor':
        icon = Icons.medical_services_rounded;
        color = const Color(0xFF009E8F);
        break;
      case 'phone':
        icon = Icons.phone_android_rounded;
        color = const Color(0xFF087F7A);
        break;
      default:
        icon = Icons.emergency_rounded;
        color = const Color(0xFFDC2626);
        break;
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFE8FAF8),
      child: Center(
        child: Icon(icon, size: 90, color: color),
      ),
    );
  }
}
