import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/errors/app_exception.dart';

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
    if (token != null && token.isNotEmpty) return true;

    if (_firebaseAuth != null) {
      try {
        final user = _firebaseAuth!.currentUser;
        if (user != null && user.uid.isNotEmpty) return true;
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionKey) ?? false;
  }

  Future<String> getCurrentUserId() async {
    final userMap = await _apiClient.getStoredUser();
    if (userMap != null && userMap.containsKey('_id')) {
      return userMap['_id'].toString();
    }

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

  /// Sign In with MongoDB Node.js Backend & Firebase Sync
  Future<dynamic> signIn(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw AuthenticationException('Email and password are required.');
    }

    try {
      // 1. Authenticate with MongoDB Backend API
      final res = await _apiClient.post('/auth/login', body: {
        'email': cleanEmail,
        'password': password,
      });

      if (res['success'] == true && res['token'] != null) {
        final token = res['token'].toString();
        final userMap = Map<String, dynamic>.from(res['user']);
        await _apiClient.saveAuthSession(token, userMap);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_sessionKey, true);
        await prefs.setString(_userIdKey, userMap['_id'].toString());

        // 2. Optional Firebase Sync
        if (_firebaseAuth != null) {
          try {
            await _firebaseAuth!.signInWithEmailAndPassword(email: cleanEmail, password: password);
          } catch (fbErr) {
            debugPrint('[AUTH WARNING] Firebase secondary sign-in skipped: $fbErr');
          }
        }

        return userMap;
      } else {
        throw AuthenticationException(res['message'] ?? 'Invalid credentials.');
      }
    } catch (e) {
      debugPrint('[AUTH ERROR] MongoDB Login Exception: $e');

      // Fallback to Firebase if MongoDB backend is unreachable
      if (_firebaseAuth != null) {
        try {
          final credential = await _firebaseAuth!.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          if (credential.user != null) {
            // Sync user to MongoDB Atlas
            try {
              final syncRes = await _apiClient.post('/auth/firebase-migrate', body: {
                'firebaseUid': credential.user!.uid,
                'email': cleanEmail,
                'fullName': credential.user!.displayName ?? cleanEmail.split('@')[0],
              });
              if (syncRes['success'] == true && syncRes['token'] != null) {
                await _apiClient.saveAuthSession(syncRes['token'], Map<String, dynamic>.from(syncRes['user']));
              }
            } catch (_) {}

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_sessionKey, true);
            await prefs.setString(_userIdKey, credential.user!.uid);
            return credential;
          }
        } on FirebaseAuthException catch (fbEx) {
          throw parseAuthException(fbEx);
        }
      }

      if (e is AppException) rethrow;
      throw AuthenticationException(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Sign Up with MongoDB Node.js Backend & Firebase Sync
  Future<dynamic> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();
    if (cleanEmail.isEmpty || password.isEmpty || cleanName.isEmpty) {
      throw AuthenticationException('All fields (Name, Email, Password) are required.');
    }

    try {
      // 1. Register with MongoDB Backend API
      final res = await _apiClient.post('/auth/register', body: {
        'fullName': cleanName,
        'email': cleanEmail,
        'password': password,
      });

      if (res['success'] == true && res['token'] != null) {
        final token = res['token'].toString();
        final userMap = Map<String, dynamic>.from(res['user']);
        await _apiClient.saveAuthSession(token, userMap);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_sessionKey, true);
        await prefs.setString(_userIdKey, userMap['_id'].toString());

        // 2. Optional Firebase Sync
        if (_firebaseAuth != null) {
          try {
            final cred = await _firebaseAuth!.createUserWithEmailAndPassword(email: cleanEmail, password: password);
            await cred.user?.updateDisplayName(cleanName);
          } catch (fbErr) {
            debugPrint('[AUTH WARNING] Firebase secondary sign-up skipped: $fbErr');
          }
        }

        return userMap;
      } else {
        throw AuthenticationException(res['message'] ?? 'Failed to register account.');
      }
    } catch (e) {
      debugPrint('[AUTH ERROR] MongoDB Register Exception: $e');

      // Fallback to Firebase if MongoDB backend is unreachable
      if (_firebaseAuth != null) {
        try {
          final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          if (credential.user != null) {
            try {
              await credential.user!.updateDisplayName(cleanName);
            } catch (_) {}

            final syncRes = await _apiClient.post('/auth/firebase-migrate', body: {
              'firebaseUid': credential.user!.uid,
              'email': cleanEmail,
              'fullName': cleanName,
            });
            if (syncRes['success'] == true && syncRes['token'] != null) {
              await _apiClient.saveAuthSession(syncRes['token'], Map<String, dynamic>.from(syncRes['user']));
            }

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_sessionKey, true);
            await prefs.setString(_userIdKey, credential.user!.uid);
            return credential;
          }
        } on FirebaseAuthException catch (fbEx) {
          throw parseAuthException(fbEx);
        }
      }

      if (e is AppException) rethrow;
      throw AuthenticationException(e.toString().replaceAll('Exception: ', ''));
    }
  }

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
