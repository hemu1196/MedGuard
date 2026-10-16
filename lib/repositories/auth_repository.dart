import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/errors/app_exception.dart';
import '../services/notification_service.dart';
import '../services/user_state_service.dart';

class AuthSession {
  final String token;
  final String userId;
  final String email;
  final String name;
  final bool profileCompleted;
  final Map<String, dynamic> rawUser;

  AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
    this.profileCompleted = false,
    required this.rawUser,
  });

  dynamic get user => this;
  String get uid => userId;
  String? get displayName => name;

  dynamic operator [](String key) {
    if (key == 'token' || key == 'accessToken') return token;
    if (key == 'userId' || key == 'uid' || key == '_id') return userId;
    if (key == 'user') return rawUser;
    if (key == 'profileCompleted') return profileCompleted;
    return rawUser[key];
  }
}

class AuthRepository {
  static const String _sessionKey = 'auth_user_session';
  static const String _userIdKey = 'auth_user_id';
  final ApiClient _apiClient = ApiClient();

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
    final token = await _apiClient.getToken();
    if (token != null && token.isNotEmpty) {
      final user = await _apiClient.getStoredUser();
      if (user != null) {
        return true;
      }
    }

    // If no valid JWT token, check if we can migrate/recover from Firebase Auth
    if (_firebaseAuth != null) {
      try {
        final fbUser = _firebaseAuth!.currentUser;
        if (fbUser != null && fbUser.uid.isNotEmpty) {
          try {
            final syncRes = await _apiClient.post('/auth/firebase-migrate', body: {
              'firebaseUid': fbUser.uid,
              'email': fbUser.email,
              'fullName': fbUser.displayName ?? fbUser.email?.split('@')[0] ?? 'User',
            });
            final recoveredToken = syncRes['token'] ?? syncRes['accessToken'];
            if (recoveredToken != null && syncRes['user'] != null) {
              final userMap = Map<String, dynamic>.from(syncRes['user']);
              await _apiClient.saveAuthSession(recoveredToken.toString(), userMap);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_sessionKey, true);
              if (userMap['_id'] != null) {
                await prefs.setString(_userIdKey, userMap['_id'].toString());
              }
              return true;
            }
          } catch (e) {
            debugPrint('[AUTH] Firebase session recovery note: $e');
          }
        }
      } catch (_) {}
    }

    // Invalid or missing JWT session: clear stale local flags
    await clearStaleSession();
    return false;
  }

  Future<void> clearStaleSession() async {
    await _apiClient.clearAuthSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, false);
    await prefs.remove(_userIdKey);
  }

  Future<String> getCurrentUserId() async {
    final userMap = await _apiClient.getStoredUser();
    if (userMap != null) {
      if (userMap['_id'] != null) return userMap['_id'].toString();
      if (userMap['id'] != null) return userMap['id'].toString();
    }
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString(_userIdKey);
    if (localId != null && localId.isNotEmpty) {
      return localId;
    }
    throw AuthenticationException('Authentication required. No token provided.');
  }

  /// Sign In with MongoDB Node.js Backend & Optional Secondary Firebase Sync
  /// Sign In with MongoDB Node.js Backend & Optional Secondary Firebase Sync
  Future<AuthSession> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw AuthenticationException('Email and password are required.');
    }

    // 1. Authenticate with MongoDB Backend API
    Map<String, dynamic> res;
    try {
      res = await _apiClient.post('/auth/login', body: {
        'email': cleanEmail,
        'password': password,
      });
    } on AuthenticationException {
      // If MongoDB rejected credentials, check if this is an existing Firebase user
      // whose account has not yet synced their password to MongoDB Atlas.
      if (_firebaseAuth != null) {
        try {
          debugPrint('[AUTH] Checking secondary Firebase Auth for legacy account: $cleanEmail');
          final userCred = await _firebaseAuth!.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          if (userCred.user != null) {
            debugPrint('[AUTH] Firebase credentials verified! Syncing password to MongoDB Atlas...');
            final syncRes = await _apiClient.post('/auth/firebase-migrate', body: {
              'firebaseUid': userCred.user!.uid,
              'email': cleanEmail,
              'password': password,
              'fullName': userCred.user!.displayName ?? cleanEmail.split('@')[0],
            });
            if (syncRes['success'] == true && (syncRes['token'] != null || syncRes['accessToken'] != null)) {
              res = syncRes;
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        } catch (fbErr) {
          debugPrint('[AUTH] Secondary Firebase check note: $fbErr');
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    final token = res['token'] ?? res['accessToken'] ?? res['data']?['token'] ?? res['data']?['accessToken'];
    if (res['success'] == true && token != null) {
      final userMap = Map<String, dynamic>.from(res['user'] ?? res['data']?['user'] ?? {});
      await _apiClient.saveAuthSession(token.toString(), userMap);

      final userId = (userMap['_id'] ?? userMap['id'] ?? '').toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      if (userId.isNotEmpty) {
        await prefs.setString(_userIdKey, userId);
      }

      // 2. Optional secondary Firebase sync
      if (_firebaseAuth != null) {
        try {
          await _firebaseAuth!.signInWithEmailAndPassword(email: cleanEmail, password: password);
        } catch (fbErr) {
          debugPrint('[AUTH WARNING] Secondary Firebase sign-in skipped: $fbErr');
        }
      }

      return AuthSession(
        token: token.toString(),
        userId: userId,
        email: cleanEmail,
        name: (userMap['fullName'] ?? userMap['name'] ?? '').toString(),
        profileCompleted: res['profileCompleted'] == true || userMap['profileCompleted'] == true,
        rawUser: userMap,
      );
    } else {
      throw AuthenticationException(res['message'] ?? 'Invalid email or password.');
    }
  }

  /// Sign Up with MongoDB Node.js Backend & Optional Secondary Firebase Sync
  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    if (cleanEmail.isEmpty || password.isEmpty || cleanName.isEmpty) {
      throw AuthenticationException('All fields (Name, Email, Password) are required.');
    }

    // 1. Register with MongoDB Backend API
    final res = await _apiClient.post('/auth/register', body: {
      'fullName': cleanName,
      'email': cleanEmail,
      'password': password,
    });

    final token = res['token'] ?? res['accessToken'] ?? res['data']?['token'] ?? res['data']?['accessToken'];
    if (res['success'] == true && token != null) {
      final userMap = Map<String, dynamic>.from(res['user'] ?? res['data']?['user'] ?? {});
      await _apiClient.saveAuthSession(token.toString(), userMap);

      final userId = (userMap['_id'] ?? userMap['id'] ?? '').toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      if (userId.isNotEmpty) {
        await prefs.setString(_userIdKey, userId);
      }

      // 2. Optional secondary Firebase sync
      if (_firebaseAuth != null) {
        try {
          final cred = await _firebaseAuth!.createUserWithEmailAndPassword(email: cleanEmail, password: password);
          await cred.user?.updateDisplayName(cleanName);
        } catch (fbErr) {
          debugPrint('[AUTH WARNING] Secondary Firebase sign-up skipped: $fbErr');
        }
      }

      return AuthSession(
        token: token.toString(),
        userId: userId,
        email: cleanEmail,
        name: cleanName,
        profileCompleted: res['profileCompleted'] == true || userMap['profileCompleted'] == true,
        rawUser: userMap,
      );
    } else {
      throw AuthenticationException(res['message'] ?? 'Failed to register account.');
    }
  }

  /// Reset Password in MongoDB Atlas (preserves user data, appointments, and records)
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw AuthenticationException('Please enter a valid email address.');
    }
    if (newPassword.length < 6) {
      throw AuthenticationException('Password must be at least 6 characters.');
    }

    final res = await _apiClient.post('/auth/reset-password', body: {
      'email': cleanEmail,
      'newPassword': newPassword,
    });

    if (res['success'] != true) {
      throw AuthenticationException(res['message'] ?? 'Failed to reset password.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
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

  Future<void> signOut() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {}
    await _apiClient.clearAuthSession();

    if (_firebaseAuth != null) {
      try {
        await _firebaseAuth!.signOut();
      } catch (_) {}
    }

    // Clear in-memory profile state
    ProfileStateManager.instance.clear();

    // Cancel all scheduled OS alarms and web timers to prevent cross-account reminder leaks
    try {
      await NotificationService().cancelAllScheduledReminders();
    } catch (e) {
      debugPrint('[AUTH] cancelAllScheduledReminders note: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, false);
    await prefs.remove(_userIdKey);
  }

  Future<void> logout() => signOut();

  Future<bool> login(String username, String password) async {
    await signIn(username, password);
    return true;
  }

  AppException parseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthenticationException('No registered account found with this email address.');
      case 'wrong-password':
      case 'invalid-credential':
        return AuthenticationException('Incorrect email or password.');
      case 'email-already-in-use':
        return AuthenticationException('An account already exists with this email.');
      case 'invalid-email':
        return AuthenticationException('Please enter a valid email address.');
      case 'weak-password':
        return AuthenticationException('Your password is too weak. Please choose a stronger password.');
      case 'network-request-failed':
        return NetworkException('Unable to connect. Check your internet connection.');
      default:
        return AuthenticationException(e.message ?? 'Authentication failed.');
    }
  }
}
