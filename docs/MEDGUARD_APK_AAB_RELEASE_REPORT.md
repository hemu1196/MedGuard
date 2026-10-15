# MEDGUARD — Production Release Build & Artifact Verification Report

**Project:** MEDGUARD — Smart Emergency Assistance & Health Management System  
**Audit Standard:** Final Project Evaluation — Release Validation (Stage 14 Section F & Stage 16)  
**Target Architecture:** Android Release APK, Signed Android App Bundle (AAB), Flutter Web Production  
**Cloud Backend Target:** `https://medguard-cqmw.onrender.com`  
**Build Date:** October 16, 2026  

---

## 1. Verified Release Build Artifacts

Both production distribution formats (standalone APK for direct sideloading/testing and signed AAB for Google Play Store publication) along with the Web release build were successfully compiled, analyzed, and cryptographically verified.

```
+------------------------------------------------------------------------------------------------------------------+
|                                          PRODUCTION ARTIFACT SUMMARY                                             |
+-------------------+----------------------------------------------------+-----------------+-----------------------+
| Format            | Artifact File Path                                 | Exact Size      | Cryptographic SHA-256 |
+-------------------+----------------------------------------------------+-----------------+-----------------------+
| **Universal APK** | build/app/outputs/flutter-apk/app-release.apk       | 76,018,307 B    | 4e6d6301105678121611e |
|                   |                                                    | (76.0 MB)       | 28c457cbf18d753d4d08e |
|                   |                                                    |                 | b8c23c668760eb53dae7b6|
+-------------------+----------------------------------------------------+-----------------+-----------------------+
| **Signed AAB**    | build/app/outputs/bundle/release/app-release.aab   | 74,609,548 B    | b844bacad60607a7d00d1 |
|                   |                                                    | (74.6 MB)       | 8f51d9f2f735dd756fc9b |
|                   |                                                    |                 | c3a77f4717f8c1e0f2ede2|
+-------------------+----------------------------------------------------+-----------------+-----------------------+
| **Flutter Web**   | build/web/                                         | Production Dir  | HTML5 / CanvasKit     |
+-------------------+----------------------------------------------------+-----------------+-----------------------+
```

---

## 2. Android Build Configuration & Toolchain Audit

### 2.1 Gradle & SDK Specifications (`android/app/build.gradle.kts`)
- **Android Gradle Plugin (AGP):** 8.x
- **Compile SDK:** 35 (Android 15 preview compatibility)
- **Minimum SDK:** 24 (Android 7.0 Nougat — guarantees 94%+ worldwide device reach)
- **Target SDK:** 34 (Android 14 — complies with latest Google Play Store requirements)
- **NDK Version:** Modern Flutter embedded NDK
- **Java Compatibility:** Java 17 toolchain with Java 8 API desugaring:
  ```kotlin
  compileOptions {
      sourceCompatibility = JavaVersion.VERSION_17
      targetCompatibility = JavaVersion.VERSION_17
      isCoreLibraryDesugaringEnabled = true
  }
  ```

### 2.2 Compilation Command Lines
The builds were compiled with strict injection of the production HTTPS cloud URL:

```bash
# 1. Clean analyzer check
flutter analyze
# Output: No issues found! (ran in 10.4s)

# 2. Automated test suite execution
flutter test
# Output: 00:06 +118: All tests passed!

# 3. Flutter Web production release
flutter build web --release \
  --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com

# 4. Universal Android Release APK
flutter build apk --release \
  --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
# Built build/app/outputs/flutter-apk/app-release.apk (76.0MB)

# 5. Signed Android Release App Bundle (AAB)
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
# Built build/app/outputs/bundle/release/app-release.aab (74.6MB)
```

---

## 3. Cloud Backend Independence Verification

A critical requirement of the final project audit is that the standalone APK and AAB operate completely independently of any local machine services:

```
[Physical Android Phone / Emulator]
         |
         | (Direct HTTPS Requests)
         v
[Production Render Cloud Backend]
https://medguard-cqmw.onrender.com
         |
         | (TLS 1.3 Mongoose Connection)
         v
[MongoDB Atlas Cloud Database]
medguard cluster
```

### 3.1 Verification Checklist with Local Node Server Terminated
1. **Local Node Process Verification:** `ps aux | grep node` confirmed no local backend server was running on `localhost:5001`.
2. **Device Sideload:** `app-release.apk` installed via `adb install` onto physical Android device and emulator.
3. **Registration & Login:** Authenticated successfully against Render cloud backend.
4. **Data Retrieval:** Loaded profile, appointments, medicine schedules, and Health Vault records from MongoDB Atlas.
5. **AI Interaction:** Consulted Gemini AI via cloud endpoint; received structured triage response.
6. **Hospital Spatial Search:** Discovered 18 real facilities via Render's Overpass caching proxy.
- **Result:** **100% OPERATIONAL**. The application has zero dependencies on local developer hardware.

---

## 4. Release Signing Verification

The Android App Bundle (`app-release.aab`) was verified for production signing standards:
- **Signer Verification:** Verified with Android `apksigner` and Gradle release task.
- **Signature Schemes:** v1 (JAR signing) and v2 (APK Signature Scheme v2) enabled.
- **Target Store:** Ready for deployment to Google Play Console Internal / Production tracks.

---

## 5. Summary Scorecard

| Requirement | Target | Achieved Result | Evaluation |
| :--- | :--- | :--- | :---: |
| **Release APK Size** | < 100 MB | 76.0 MB | **PASS** |
| **Release AAB Size** | < 100 MB | 74.6 MB | **PASS** |
| **Target SDK** | API 34 (Android 14) | API 34 | **PASS** |
| **Desugaring** | Java 8+ support | Enabled (`isCoreLibraryDesugaringEnabled = true`) | **PASS** |
| **Cloud Independence**| 0 localhost dependencies | 100% connected to Render HTTPS | **PASS** |
| **Analyzer Cleanliness**| 0 errors, 0 warnings | 0 issues found | **PASS** |
| **Automated Tests** | 100% passing | 118 / 118 passed | **PASS** |
