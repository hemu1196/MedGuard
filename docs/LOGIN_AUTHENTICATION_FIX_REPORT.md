# MEDGUARD — Login & Password Authentication Root Cause Fix Report

**Date:** October 11, 2026  
**Project:** MEDGUARD — Smart Emergency Assistance & Health Management System  
**Frontend:** Flutter / Dart (Flutter Web, Android Emulator, Physical Android)  
**Backend:** Node.js + Express + Mongoose (`https://medguard-cqmw.onrender.com`)  
**Database:** MongoDB Atlas (`medguard` on `MedGuardCluster`)  

---

## 1. Executive Summary

This report documents the resolution of the **"Invalid email or password"** authentication issue following the migration from Firebase to Node.js, Express, JWT, and MongoDB Atlas.

All root causes have been resolved in the codebase, verified with a 24-test backend authentication test suite, validated with all 77 Flutter tests, and verified across production release builds.

---

## 2. Root Cause Analysis

1. **Email Casing and Whitespace Normalization**:
   - Mobile keyboards and Web autocompletion frequently introduce capitalized initials (e.g., `User@example.com`) or trailing whitespace (e.g., `user@example.com `).
   - In MongoDB, queries via `User.findOne({ email })` perform exact string matching. Queries without explicit `.trim().toLowerCase()` failed to match trimmed, lowercase database records.
2. **Legacy Firebase Account Password Desynchronization**:
   - When users were originally synchronized from Firebase via `firebaseMigrate`, MongoDB user records were populated with random string passwords (`Math.random().toString(36)...`) because Firebase does not expose plaintext passwords or standard bcrypt hashes.
   - Consequently, when users entered their real passwords into the new MongoDB-backed login form, `bcrypt.compare` failed against the random password hash, returning `401 Unauthorized: Invalid email or password.`
3. **Missing MongoDB Password Reset Endpoint**:
   - The Express backend lacked a `POST /api/auth/reset-password` endpoint.
   - The Flutter UI's "Forgot Password?" dialog previously called Firebase's `sendPasswordResetEmail()`, which had no effect on passwords stored in MongoDB Atlas.
4. **Pre-Save Document Hooks on Login**:
   - Updating `lastLoginAt` using `await user.save()` executed document-level lifecycle middleware unnecessarily instead of an atomic `$set` update.

---

## 3. Implemented Solutions

### A. Backend (`backend/src/controllers/authController.js` & `backend/src/routes/authRoutes.js`)
- **Strict Email Normalization**:
  - All endpoints (`register`, `login`, `resetPassword`, `firebaseMigrate`) enforce `String(email).trim().toLowerCase()`.
- **Atomic Login Update**:
  - `login` now executes `User.updateOne({ _id: user._id }, { $set: { lastLoginAt: new Date() } })`, preventing unintended pre-save hook invocations while maintaining fast response times.
- **Dedicated Password Reset Endpoint (`POST /api/auth/reset-password`)**:
  - Validates normalized email and minimum password length (>= 6 characters).
  - Finds existing user in MongoDB Atlas (`User.findOne({ email: normalizedEmail })`).
  - Sets `user.password = newPassword` (automatically hashed via bcrypt with salt factor 10).
  - Preserves all existing user profiles, health vault records, appointments, emergency contacts, and water logs.
  - Generates a fresh JWT token and logs an audit event (`PASSWORD_RESET`).
- **Enhanced Firebase Migration Sync**:
  - `firebaseMigrate` accepts `password` and updates the user's MongoDB password with a real bcrypt hash, allowing subsequent logins to authenticate directly against MongoDB.

### B. Flutter Client (`lib/repositories/auth_repository.dart` & `lib/screens/auth/login_page.dart`)
- **Seamless Password Migration on Login**:
  - In `AuthRepository.signIn`, if MongoDB returns 401 and Firebase Auth is available, it tests credentials against Firebase Auth.
  - Upon successful Firebase verification, it automatically syncs the password to MongoDB Atlas via `/auth/firebase-migrate`.
  - Future logins immediately authenticate directly against MongoDB Atlas without needing Firebase.
- **Interactive Password Reset Modal**:
  - Enhanced `_openForgotPasswordDialog` in `LoginPage`:
    - Allows users to enter registered email and set a new password.
    - Password visibility toggle (obscured by default).
    - Confirmation field matching validation.
    - Directly updates credentials in MongoDB Atlas via `_authRepository.resetPassword()`.
    - Automatically pre-fills login fields upon successful password reset.

---

## 4. Test & Verification Evidence

### A. Backend Authentication Suite (`backend/scripts/verifyLoginFix.js`)
```text
================================================================
MEDGUARD — LOGIN & PASSWORD AUTHENTICATION VERIFICATION SUITE
================================================================
[PASS 1] Registration returns HTTP 201
[PASS 2] Registration returns success=true
[PASS 3] Registration returns JWT token
[PASS 4] Registration returns accessToken alias
[PASS 5] Registration does NOT leak password or hash
[PASS 6] Registration normalized email in database
[PASS 7] Duplicate registration rejected with HTTP 400
[PASS 8] Duplicate registration returns clear error message
[PASS 9] Login with correct credentials returns HTTP 200
[PASS 10] Login returns success=true
[PASS 11] Login returns valid JWT
[PASS 12] Login does NOT leak password hash
[PASS 13] Login with cased & spaced email succeeds (normalized)
[PASS 14] Login with wrong password returns HTTP 401
[PASS 15] Login returns generic error message
[PASS 16] Login with unknown email returns HTTP 401
[PASS 17] Unknown email returns identical generic message (no enumeration)
[PASS 18] Password reset returns HTTP 200
[PASS 19] Password reset returns success=true
[PASS 20] Password reset returns new JWT
[PASS 21] Old password rejected with HTTP 401 after reset
[PASS 22] New password succeeds with HTTP 200 after reset
[PASS 23] User profile preserved after password reset
[PASS 24] MongoDB Atlas users collection preserved intact

================================================================
VERIFICATION COMPLETE: 24/24 TESTS PASSED!
================================================================
```

### B. Flutter Test Suite
```text
$ flutter test
00:04 +77: All tests passed!
```

### C. Static Analysis
```text
$ dart analyze lib/
Analyzing lib...
No issues found!
```

### D. Production Builds
- **Flutter Web Release**: `build/web` (Built in 24.7s)
- **Android Release APK**: `build/app/outputs/flutter-apk/app-release.apk` (75.0 MB, Built in 25.6s)
- Compiled with: `--dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com`

---

## 5. Security & Privacy Guarantees
- **No Password Exposure**: Passwords and password hashes are never logged, never returned in API payloads (`userSchema.methods.toJSON` removes `password`), and never stored in plaintext.
- **Account Enumeration Protection**: Both wrong passwords and non-existent emails return an identical HTTP 401 response: `{"success":false,"message":"Invalid email or password."}`.
- **Data Integrity**: Existing user documents, `_id` identifiers, medical records, and appointment relationships in `medguard` are preserved without deletion or recreation.
