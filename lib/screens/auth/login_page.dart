import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/errors/app_exception.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authRepository = AuthRepository();
  final _profileRepository = ProfileRepository();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      debugPrint('[AUTH] Attempting Firebase Sign-In for email: $email');
      final credential = await _authRepository.signIn(email, password);
      final userId = credential.user?.uid ?? await _authRepository.getCurrentUserId();

      debugPrint('[AUTH] Firebase Sign-In successful. User UID: $userId');
      final profileExists = await _profileRepository.profileExists(userId);
      debugPrint('[PROFILE] Profile exists check for $userId: $profileExists');

      if (!mounted) return;

      if (profileExists) {
        debugPrint('[NAVIGATION] Navigating to Dashboard');
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
        );
      } else {
        debugPrint('[NAVIGATION] Navigating to Profile Setup');
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.profileSetup,
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[AUTH ERROR] Login failed: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : e.toString();
        _isLoading = false;
      });
    } finally {
      if (mounted && _errorMessage == null) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address to receive a password reset link:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address')),
                );
                return;
              }
              Navigator.of(dialogContext).pop();
              try {
                await _authRepository.sendPasswordResetEmail(email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset link sent to $email'),
                    backgroundColor: AppTheme.accentGreen,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reset failed: ${e.toString()}'),
                    backgroundColor: AppTheme.accentRed,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _openCreateAccountDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool isRegistering = false;
    bool obscurePass = true;
    bool obscureConfirm = true;
    String? registerErrorTitle;
    String? registerError;
    bool showSignInAction = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) {
          final isDark = Theme.of(builderContext).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryTeal),
                ),
                const SizedBox(width: 12),
                const Text('Create MedGuard Account'),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Structured Error Banner
                    if (registerError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A1A) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.red.shade900 : Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    registerErrorTitle ?? 'Registration Error',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.red.shade200 : Colors.red.shade800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              registerError!,
                              style: TextStyle(
                                color: isDark ? Colors.red.shade100 : Colors.red.shade900,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            if (showSignInAction) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryTeal,
                                    side: const BorderSide(color: AppTheme.primaryTeal),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onPressed: () {
                                    final email = emailCtrl.text.trim();
                                    Navigator.of(dialogContext).pop();
                                    if (email.isNotEmpty) {
                                      _emailController.text = email;
                                    }
                                  },
                                  icon: const Icon(Icons.login_rounded, size: 16),
                                  label: const Text('Sign In to Existing Account'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Form Fields
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'e.g. Hemachandra',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'name@example.com',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'At least 6 characters',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePass = !obscurePass;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password *',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        hintText: 'Re-enter password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isRegistering ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isRegistering
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final pass = passCtrl.text;
                        final confirm = confirmPassCtrl.text;

                        // Field-level Validation before calling Firebase
                        if (name.isEmpty) {
                          debugPrint('[REGISTER] Validation failed: Name required');
                          setDialogState(() {
                            registerErrorTitle = 'Full Name Required';
                            registerError = 'Please enter your full name.';
                            showSignInAction = false;
                          });
                          return;
                        }
                        if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                          debugPrint('[REGISTER] Validation failed: Invalid email');
                          setDialogState(() {
                            registerErrorTitle = 'Invalid Email';
                            registerError = 'Please enter a valid email address.';
                            showSignInAction = false;
                          });
                          return;
                        }
                        if (pass.length < 6) {
                          debugPrint('[REGISTER] Validation failed: Weak password');
                          setDialogState(() {
                            registerErrorTitle = 'Weak Password';
                            registerError = 'Password must contain at least 6 characters.';
                            showSignInAction = false;
                          });
                          return;
                        }
                        if (pass != confirm) {
                          debugPrint('[REGISTER] Validation failed: Password mismatch');
                          setDialogState(() {
                            registerErrorTitle = 'Password Mismatch';
                            registerError = 'Passwords do not match.';
                            showSignInAction = false;
                          });
                          return;
                        }

                        debugPrint('[REGISTER] Register button pressed');
                        debugPrint('[REGISTER] Validation passed');

                        setDialogState(() {
                          isRegistering = true;
                          registerError = null;
                          registerErrorTitle = null;
                          showSignInAction = false;
                        });

                        try {
                          debugPrint('[REGISTER] Calling AuthRepository.signUp');
                          final credential = await _authRepository.signUp(
                            name: name,
                            email: email,
                            password: pass,
                          );

                          final user = credential.user;
                          if (user == null) {
                            throw AuthenticationException('Account creation did not return a Firebase user.');
                          }

                          debugPrint('[REGISTER] SUCCESS UID=${user.uid}');

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Account created for $name! Let\'s set up your profile.'),
                              backgroundColor: AppTheme.accentGreen,
                            ),
                          );

                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.profileSetup,
                            (route) => false,
                          );
                        } on AppException catch (e) {
                          debugPrint('[REGISTER] AppException: ${e.message}');
                          final isExistingAccount = e.message.contains('already exists') || e.message.contains('signing in');
                          setDialogState(() {
                            registerErrorTitle = isExistingAccount ? 'Account Already Exists' : 'Registration Failed';
                            registerError = e.message;
                            showSignInAction = isExistingAccount;
                          });
                        } on FirebaseAuthException catch (e) {
                          debugPrint('[REGISTER] FirebaseAuthException: ${e.code} ${e.message}');
                          final appEx = _authRepository.parseAuthException(e);
                          final isExistingAccount = e.code == 'email-already-in-use';
                          setDialogState(() {
                            registerErrorTitle = isExistingAccount ? 'Account Already Exists' : 'Registration Failed';
                            registerError = appEx.message;
                            showSignInAction = isExistingAccount;
                          });
                        } catch (e, stackTrace) {
                          debugPrint('[REGISTER] Unexpected exception type: ${e.runtimeType}');
                          debugPrint('[REGISTER] Unexpected exception: $e');
                          debugPrintStack(stackTrace: stackTrace);
                          setDialogState(() {
                            registerErrorTitle = 'Registration Failed';
                            registerError = 'Unable to create your account. Please try again.';
                            showSignInAction = false;
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isRegistering = false;
                            });
                          }
                        }
                      },
                child: isRegistering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Register Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 56,
                        height: 56,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.health_and_safety_rounded,
                          size: 48,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'MEDGUARD',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTeal,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Intelligent Health & Emergency Companion',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Email Address Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'Enter your email address',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email address';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Enter your password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Options Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                              activeColor: AppTheme.primaryTeal,
                            ),
                            const Text(
                              'Remember me',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        Flexible(
                          child: TextButton(
                            onPressed: _openForgotPasswordDialog,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryTeal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Login Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Register Account Link
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: _openCreateAccountDialog,
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
