import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/errors/app_exception.dart';

class AuthRepository {
  static const String _sessionKey = 'auth_user_session';
  static const String _userIdKey = 'auth_user_id';

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth? get _firebaseAuth {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _firebaseAuth?.currentUser;

  Stream<User?> get authStateChanges =>
      _firebaseAuth?.authStateChanges() ?? const Stream.empty();

  Future<bool> isAuthenticated() async {
    if (_firebaseAuth != null) {
      try {
        final user = _firebaseAuth!.currentUser;
        if (user != null && user.uid.isNotEmpty) return true;
      } catch (_) {}
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionKey) ?? false;
  }

  Future<String> getCurrentUserId() async {
    if (_firebaseAuth != null) {
      try {
        final user = _firebaseAuth!.currentUser;
        if (user != null && user.uid.isNotEmpty) {
          return user.uid;
        }
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString(_userIdKey);
    if (localId != null && localId.isNotEmpty) {
      return localId;
    }
    throw AuthenticationException('No authenticated user session found. Please sign in again.');
  }

  /// Real Firebase Email/Password Sign-In
  Future<UserCredential> signIn(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw AuthenticationException('Email and password are required.');
    }

    if (_firebaseAuth == null) {
      // Fallback session storage for offline or test mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      await prefs.setString(_userIdKey, 'offline_user_1');
      throw AuthenticationException('Firebase service is not initialized.');
    }

    try {
      final credential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      if (credential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_sessionKey, true);
        await prefs.setString(_userIdKey, credential.user!.uid);
        return credential;
      } else {
        throw AuthenticationException('Sign in failed: User account not found.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH ERROR] FirebaseAuthException: ${e.code} - ${e.message}');
      throw parseAuthException(e);
    } catch (e) {
      debugPrint('[AUTH ERROR] Unexpected sign-in error: $e');
      throw AuthenticationException('Authentication failed: ${e.toString()}');
    }
  }

  /// Real Firebase Email/Password Registration
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();
    if (cleanEmail.isEmpty || password.isEmpty || cleanName.isEmpty) {
      throw AuthenticationException('All fields (Name, Email, Password) are required.');
    }

    if (_firebaseAuth == null) {
      throw AuthenticationException('Firebase service is not initialized.');
    }

    try {
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      if (credential.user != null) {
        try {
          await credential.user!.updateDisplayName(cleanName);
        } catch (e) {
          debugPrint('[AUTH] updateDisplayName failed/bypassed: $e');
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_sessionKey, true);
        await prefs.setString(_userIdKey, credential.user!.uid);
        return credential;
      } else {
        throw AuthenticationException('Registration failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      throw parseAuthException(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthenticationException('Unable to create your account. Please try again.');
    }
  }

  /// Sends password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw AuthenticationException('Please enter a valid email address.');
    }
    if (_firebaseAuth != null) {
      try {
        await _firebaseAuth!.sendPasswordResetEmail(email: cleanEmail);
      } on FirebaseAuthException catch (e) {
        throw parseAuthException(e);
      }
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (_firebaseAuth != null) {
      try {
        await _firebaseAuth!.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, false);
    await prefs.remove(_userIdKey);
  }

  Future<void> logout() => signOut();

  /// Legacy helper method mapping to signIn for backwards compatibility
  Future<bool> login(String username, String password) async {
    await signIn(username, password);
    return true;
  }

  /// Converts FirebaseAuthException into user-friendly AppException messages
  AppException parseAuthException(FirebaseAuthException e) {
    final code = e.code.toLowerCase();

    if (code.contains('api-key-not-valid') || code.contains('invalid-api-key')) {
      return AuthenticationException(
        'Firebase configuration is invalid. Please verify the Firebase API key.',
      );
    }

    switch (e.code) {
      case 'user-not-found':
        return AuthenticationException('No registered account found with this email address.');
      case 'wrong-password':
      case 'invalid-credential':
        return AuthenticationException('Incorrect email or password.');
      case 'email-already-in-use':
        return AuthenticationException('An account already exists with this email. Please sign in instead.');
      case 'invalid-email':
        return AuthenticationException('Please enter a valid email address.');
      case 'weak-password':
        return AuthenticationException('Your password is too weak. Please choose a stronger password.');
      case 'operation-not-allowed':
        return AuthenticationException('Email/password registration is not enabled.');
      case 'network-request-failed':
        return NetworkException('Unable to connect. Check your internet connection and try again.');
      case 'too-many-requests':
        return AuthenticationException('Too many attempts. Please wait and try again.');
      default:
        return AuthenticationException(e.message ?? 'Unable to create your account. Please try again.');
    }
  }
}
