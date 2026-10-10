# MEDGUARD Profile Persistence, Age-Saving & Onboarding Fix Report

**Project:** MEDGUARD — Smart Health Emergency Assistance & Health Management System  
**Date:** October 11, 2026  
**Status:** Completed & Verified (51/51 tests passing, `flutter analyze` 0 issues)

---

## 1. Executive Summary

This report documents the resolution of critical profile data persistence, age saving, and onboarding flow navigation issues in MEDGUARD. 

Previously:
1. Profile attributes entered on onboarding (specifically `dateOfBirth`, `age`, emergency contacts, height, and weight) failed to persist into MongoDB Atlas (`medguard.users`).
2. App navigated to the Dashboard even when backend persistence failed or returned errors.
3. Reloading or navigating back to the Profile screen presented blank or missing fields due to schema stripping and repository payload omissions.

All issues have been resolved. The profile completion state is now strictly **server-authoritative**, forms maintain unsaved state upon network/validation errors, and all 16 profile fields reliably persist into MongoDB Atlas.

---

## 2. Root Causes Identified & Fixes Applied

### A. Repository Payload Omissions (`lib/repositories/profile_repository.dart`)
- **Root Cause:** `ProfileRepository.saveProfile()` constructed an API request JSON body that omitted `dateOfBirth`, `age`, `phoneNumber`, `emergencyContactName`, `emergencyPhone`, `emergencyCountryCode`, and `emergencyRelationship`.
- **Fix:** Updated `ProfileRepository.saveProfile()` to transmit all profile fields in the POST/PATCH request payload to `/api/auth/profile` and `/api/users/me`.

### B. Mongoose Strict Schema Stripping (`backend/src/models/User.js`)
- **Root Cause:** Mongoose 9 enforces `strict: true` by default. The `User.js` schema lacked field definitions for `dateOfBirth`, `emergencyContactName`, `emergencyCountryCode`, `emergencyPhone`, `emergencyRelationship`, and `profileCompleted`. Mongoose automatically stripped these properties before persisting to MongoDB Atlas.
- **Fix:** Updated `User.js` schema to include:
  - `dateOfBirth`: Date type
  - `emergencyContactName`, `emergencyCountryCode`, `emergencyPhone`, `emergencyRelationship`: String types
  - `profileCompleted`: Boolean type
  - Pre-save hook to calculate `age` from `dateOfBirth` if `dateOfBirth` is provided, and automatically calculate `profileCompleted = true` when required fields (`fullName`, `gender`, `bloodGroup`, `heightCm`, `weightKg`) are filled.

### C. Backend API Controller (`backend/src/controllers/authController.js` & `backend/src/routes/userRoutes.js`)
- **Root Cause:** `authController.updateProfile` maintained a whitelisted array `allowedUpdates` that excluded `dateOfBirth`, `emergencyContactName`, `emergencyCountryCode`, `emergencyPhone`, and `emergencyRelationship`.
- **Fix:** Expanded `allowedUpdates` to accept and set all profile parameters. Added dedicated user profile endpoints (`/api/users/me`) supporting GET, PATCH, and PUT.

### D. Model Age Calculation & Serialization (`lib/models/user_profile.dart`)
- **Root Cause:** Age was not dynamically recalculated when `dateOfBirth` was modified, and copyWith lacked proper explicit age retention.
- **Fix:** Updated `UserProfile` model:
  - Computed `calculatedAge` getter based on calendar year & birthday occurrence.
  - Preserved explicit `age` when `dateOfBirth` is not set.
  - Implemented accurate `fromMap` and `toMap` serialization matching backend field schemas.

### E. Onboarding Form & Navigation Control (`lib/screens/onboarding/health_profile_page.dart`)
- **Root Cause:** Navigation to `MainScreen` occurred unconditionally in `finally` blocks or before waiting for server response confirmation.
- **Fix:** 
  - Added strict validation for DOB, Height (> 0), and Weight (> 0).
  - Preserved form state and displayed feedback SnackBar on validation or API failures without navigating away.
  - Navigated to Dashboard **only** after receiving HTTP 200/201 with `success: true` and `profileCompleted: true` from the backend API.

---

## 3. Profile Field Mapping

| Flutter Field | API Property | MongoDB Schema Field | Data Type | Persistence Status |
|---|---|---|---|---|
| Full Name | `fullName` / `name` | `fullName` | String | **VERIFIED** |
| Date of Birth | `dateOfBirth` | `dateOfBirth` | Date (ISO8601) | **VERIFIED** |
| Age | `age` | `age` | Number | **VERIFIED** |
| Gender | `gender` | `gender` | String | **VERIFIED** |
| Blood Group | `bloodGroup` | `bloodGroup` | String | **VERIFIED** |
| Height | `heightCm` / `height` | `heightCm` | Number | **VERIFIED** |
| Weight | `weightKg` / `weight` | `weightKg` | Number | **VERIFIED** |
| Known Allergies | `allergies` | `allergies` | [String] | **VERIFIED** |
| Existing Conditions | `chronicConditions` / `existingConditions` | `chronicConditions` | [String] | **VERIFIED** |
| Current Medications | `emergencyMedicalInfo` / `currentMedications` | `emergencyMedicalInfo` | String | **VERIFIED** |
| Emergency Contact Name | `emergencyContactName` | `emergencyContactName` | String | **VERIFIED** |
| Emergency Country Code | `emergencyCountryCode` | `emergencyCountryCode` | String | **VERIFIED** |
| Emergency Phone | `emergencyPhone` / `phoneNumber` | `emergencyPhone` | String | **VERIFIED** |
| Emergency Relationship | `emergencyRelationship` | `emergencyRelationship` | String | **VERIFIED** |
| Profile Picture URL | `profilePictureUrl` / `profileImagePath` | `profilePictureUrl` | String | **VERIFIED** |
| Profile Completed Status | `profileCompleted` / `isProfileComplete` | `profileCompleted` | Boolean | **VERIFIED** |

---

## 4. Verification & Testing

1. **Database Diagnostic Test:**
   ```bash
   cd backend
   npm run test:db
   ```
   *Result:* Connected to `medguard` cluster, write/read verification passed.

2. **Backend Daemon Status:**
   Server active on `http://localhost:5001/api/health` returning `{"status":"healthy","mongodb":"connected"}`.

3. **Flutter Static Analysis:**
   ```bash
   flutter analyze
   ```
   *Result:* `No issues found!`

4. **Flutter Unit & Repository Tests:**
   ```bash
   flutter test
   ```
   *Result:* `51/51 tests passed!`

---

## 5. Execution Instructions

### Starting the Backend
```bash
cd /Users/hemachandra/Mobile_App_Dev/med_ai/backend
node index.js
```

### Running Flutter App
- **Web:** `flutter run -d chrome`
- **Android Emulator / Device:** `flutter run -d android`
