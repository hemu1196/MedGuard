import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import '../screens/auth/login_page.dart';
import '../screens/onboarding/health_profile_page.dart';
import '../screens/main_navigation_frame.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  bool _isLoading = true;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndProfile();
  }

  Future<void> _checkAuthAndProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[AUTHGATE] Checking authentication state...');
      final isAuth = await _authRepository.isAuthenticated();
      debugPrint('[AUTHGATE] isAuthenticated result: $isAuth');

      if (!isAuth) {
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _isLoading = false;
          });
        }
        return;
      }

      final userId = await _authRepository.getCurrentUserId();
      debugPrint('[AUTHGATE] Current User UID: $userId');

      final hasProfile = await _profileRepository.profileExists(userId);
      debugPrint('[AUTHGATE] profileExists result for $userId: $hasProfile');

      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _hasProfile = hasProfile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AUTHGATE ERROR] Startup verification failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.health_and_safety_rounded,
                    size: 40,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: AppTheme.primaryTeal,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              const Text(
                'MEDGUARD',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primaryTeal,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Verifying secure medical session...',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.accentRed),
                const SizedBox(height: 16),
                const Text(
                  'Connection Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _checkAuthAndProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Session Check'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const LoginPage();
    }

    if (!_hasProfile) {
      return const HealthProfilePage();
    }

    return const MainNavigationFrame(initialIndex: 0);
  }
}
