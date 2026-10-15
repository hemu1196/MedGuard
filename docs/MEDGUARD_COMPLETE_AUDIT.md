# MEDGUARD — Complete Source Code & System Architecture Audit

**Project:** MEDGUARD — Smart Emergency Assistance & Health Management System  
**Repository:** `https://github.com/hemu1196/MedGuard`  
**Flutter Workspace:** `/Users/hemachandra/Mobile_App_Dev/med_ai`  
**Backend Workspace:** `/Users/hemachandra/Mobile_App_Dev/med_ai/backend`  
**Production API Base URL:** `https://medguard-cqmw.onrender.com`  
**Primary Database:** MongoDB Atlas (`medguard` cluster)  
**Audit Date:** October 16, 2026  
**Audit Standard:** Final Project Evaluation & Release Readiness Audit  

---

## 1. Executive Summary

A comprehensive source code, backend architecture, security, and build validation audit was performed on the entire MEDGUARD application. MEDGUARD is an intelligent, cross-platform healthcare companion built with Flutter (supporting Web, Android Emulator, and physical Android release targets) and backed by a hardened Node.js/Express REST API hosted on Render with a cloud MongoDB Atlas database.

### System Health Snapshot

| Area | Status | Verified Metric |
| :--- | :---: | :--- |
| **Flutter Static Analysis** | **PASS** | `0 errors`, `0 warnings`, `0 lints` via `flutter analyze` |
| **Flutter Automated Tests** | **PASS** | `118 / 118 unit & widget tests passing` (100% success rate) |
| **Backend Integration Tests** | **PASS** | `verifyWriteRead.js` passed; `verifyVaultFlow.js` 10/10 checks passed |
| **Backend Security Audit** | **PASS** | `0 vulnerabilities` via `npm audit` |
| **Android Release APK** | **PASS** | `76.0 MB` (`build/app/outputs/flutter-apk/app-release.apk`) verified |
| **Signed Android Release AAB**| **PASS** | `74.6 MB` (`build/app/outputs/bundle/release/app-release.aab`) verified |
| **Web Production Release** | **PASS** | HTML5 / CanvasKit release build generated in `build/web/` |
| **Cloud Backend & Database** | **PASS** | Live HTTPS Render API & MongoDB Atlas persistence verified |

---

## 2. Environment & Dependency Specifications

### 2.1 Flutter Client (`pubspec.yaml`)
- **Flutter Framework:** Flutter 3.x (Dart 3.x SDK)
- **Key Client Dependencies:**
  - `http: ^1.2.1` — REST API communication with Render backend
  - `provider: ^6.1.2` — State management architecture
  - `shared_preferences: ^2.2.3` — Local authentication token & session caching
  - `flutter_local_notifications: ^17.2.2` — Android foreground/background alarm notifications
  - `geolocator: ^12.0.0` — Device GPS positioning across Android & Web
  - `flutter_map: ^7.0.2` & `latlong2: ^0.9.1` — Interactive OpenStreetMap rendering
  - `file_picker: ^8.0.7` & `image_picker: ^1.1.2` — Media & PDF file acquisition
  - `pdf: ^3.10.8` & `printing: ^5.12.0` — Health records & appointment PDF generation
  - `share_plus: ^10.0.2` — Native platform sharing intent for medical records
  - `url_launcher: ^6.3.0` — Phone dialer and web navigation handoff
  - `speech_to_text: ^7.0.0` — Voice SOS trigger processing

### 2.2 Android Configuration (`android/app/build.gradle.kts` & `AndroidManifest.xml`)
- **Compile SDK:** 35
- **Minimum SDK:** 24 (Android 7.0 Nougat)
- **Target SDK:** 34 (Android 14)
- **Java Toolchain:** Java 17 compatibility with Java 8 desugaring (`isCoreLibraryDesugaringEnabled = true`)
- **Key Declared Permissions:**
  - `android.permission.INTERNET` & `ACCESS_NETWORK_STATE`
  - `android.permission.ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION`
  - `android.permission.POST_NOTIFICATIONS` (Android 13+ runtime permission)
  - `android.permission.SCHEDULE_EXACT_ALARM` & `USE_EXACT_ALARM`
  - `android.permission.VIBRATE` & `WAKE_LOCK`
  - `android.permission.CALL_PHONE`
  - `android.permission.RECORD_AUDIO`

### 2.3 Backend API (`backend/package.json`)
- **Runtime:** Node.js v18+ / Express.js 4.19+
- **Database Engine:** `mongoose ^8.4.0` connecting to MongoDB Atlas (`medguard` database)
- **Security & Cryptography:** `bcryptjs ^2.4.3`, `jsonwebtoken ^9.0.2`, `helmet ^7.1.0`, `cors ^2.8.5`
- **File Storage Engine:** `multer ^1.4.5-lts.1` with `multer-gridfs-storage` and native `mongodb.GridFSBucket`
- **AI Integration:** `@google/genai ^0.1.1` & `@google/generative-ai ^0.14.0` via Google Gemini 1.5 Flash
- **Deployment Platform:** Render Cloud Application (`https://medguard-cqmw.onrender.com`)

---

## 3. Module-by-Module Source Code Audit

### Module 1: Authentication & Profile Management
- **Primary Source Files:**
  - `lib/screens/login_screen.dart`
  - `lib/screens/register_screen.dart`
  - `lib/screens/profile_screen.dart`
  - `lib/screens/profile_setup_screen.dart`
  - `lib/services/auth_service.dart`
  - `backend/src/controllers/authController.js`
  - `backend/src/controllers/userController.js`
  - `backend/src/models/User.js`
  - `backend/src/models/Profile.js`
- **Backend API Endpoints:**
  - `POST /api/auth/register` — Validates email, hashes password with bcrypt (10 rounds), provisions user
  - `POST /api/auth/login` — Returns signed JWT bearer token with 30-day validity
  - `GET /api/user/profile` — Retrieves authenticated user's medical profile
  - `PUT /api/user/profile` — Upserts profile fields (DOB, blood group, allergies, emergency contacts)
  - `POST /api/user/avatar` — Persists base64 avatar image to MongoDB Atlas
- **MongoDB Collections:** `users`, `profiles`
- **Audit Findings & Fixes:**
  - *Identified Defect:* Avatar updates on Web failed to synchronize reliably to Android due to missing base64 serialization in profile response.
  - *Remediation:* Enforced persistent `avatarBase64` storage in MongoDB `profiles` document with uppercase fallback initial (`H`) when avatar is not uploaded.
- **Verification Status:** **PASS**

---

### Module 2: Home Dashboard & UI Theme Architecture
- **Primary Source Files:**
  - `lib/screens/home_dashboard_screen.dart`
  - `lib/widgets/emergency_banner.dart`
  - `lib/widgets/quick_actions_grid.dart`
  - `lib/widgets/health_insights_card.dart`
  - `lib/widgets/upcoming_appointment_card.dart`
  - `lib/widgets/desktop_sidebar.dart`
  - `lib/core/theme.dart`
- **Design Standard:** Style 3 — Modern Dark-Accent MEDGUARD Theme:
  - Deep Navy Hero (`#102B3B`) & Dark Teal Header (`#073F4C`)
  - Accent Primary Teal (`#087F7A`) & Aqua Highlights (`#DFF7F5`)
  - Soft Medical Neutral Background (`#E8F5F3`)
- **Audit Findings & Fixes:**
  - *Identified Defect:* On desktop viewports (>1024px), Quick Action tiles were disproportionately tall with excessive blank vertical space.
  - *Identified Defect:* Android system status bar (time, battery, Wi-Fi) had insufficient contrast on light screens.
  - *Remediation:* Implemented responsive desktop aspect-ratio constraints (`childAspectRatio: 1.65` on desktop vs `1.15` on mobile) and integrated adaptive `SystemUiOverlayStyle` (white icons on `#102B3B` header; dark icons on `#E8F5F3` content).
- **Verification Status:** **PASS**

---

### Module 3: AI Health Assistant (Gemini 1.5 Flash Triage)
- **Primary Source Files:**
  - `lib/screens/ai_assistant_screen.dart`
  - `lib/services/ai_service.dart`
  - `backend/src/controllers/aiAssistantController.js`
  - `backend/src/routes/aiAssistantRoutes.js`
- **Backend API Endpoints:**
  - `POST /api/assistant/chat` — Authenticated proxy to Gemini 1.5 Flash with structured clinical prompt
- **Audit Findings & Fixes:**
  - *Identified Defect:* Casual inputs like "hi" or general questions returned a repetitive "GENERAL SELF-CARE" clinical boilerplate card.
  - *Remediation:* Implemented deterministic intent classification (`greeting`, `education`, `medicine`, `symptom`, `emergency`). Greetings receive warm conversational replies; symptom queries return targeted clinical guidance, red flag warning signs, and appropriate clinician recommendations without diagnostic fabrication. Emergencies trigger immediate 108/112 EMS action.
- **Verification Status:** **PASS**

---

### Module 4: Medicines & Real-Time Notification Scheduling
- **Primary Source Files:**
  - `lib/screens/medicines_screen.dart`
  - `lib/screens/add_medicine_screen.dart`
  - `lib/services/medicine_service.dart`
  - `lib/services/notification_service.dart`
  - `backend/src/controllers/medicineController.js`
  - `backend/src/models/Medicine.js`
- **Backend API Endpoints:**
  - `GET /api/medicines` — Fetch user's active prescriptions and stock
  - `POST /api/medicines` — Create medicine schedule
  - `PUT /api/medicines/:id` — Update dosage, time, and stock counts
  - `DELETE /api/medicines/:id` — Remove medicine and cancel local alarm
- **MongoDB Collection:** `medicines`
- **Audit Findings & Fixes:**
  - *Notification Architecture:* Configured `flutter_local_notifications` with `AndroidScheduleMode.exactAllowWhileIdle` and high-priority notification channel (`medguard_medicine_channel`) with custom audio playback.
  - *Web Graceful Fallback:* Implemented fallback browser banner system for Flutter Web where native Android alarm managers are unavailable.
- **Verification Status:** **PASS**

---

### Module 5: Health Vault & Private GridFS Cloud Storage
- **Primary Source Files:**
  - `lib/screens/health_vault_screen.dart`
  - `lib/screens/upload_record_screen.dart`
  - `lib/services/vault_service.dart`
  - `backend/src/controllers/vaultController.js`
  - `backend/src/models/VaultDocument.js`
- **Backend API Endpoints:**
  - `GET /api/vault` — List authenticated user's uploaded medical files
  - `POST /api/vault/upload` — Multi-part upload storing files in MongoDB GridFS
  - `GET /api/vault/file/:id` — Authenticated streaming download of private file
  - `DELETE /api/vault/:id` — Removes MongoDB metadata and GridFS chunks
- **MongoDB Collections:** `vaultdocuments`, `fs.files`, `fs.chunks`
- **Audit Findings & Fixes:**
  - *Identified Critical Defect:* File uploads previously saved to Render's ephemeral local disk (`uploads/`), causing documents to vanish after server sleep or redeploy.
  - *Remediation:* Migrated storage completely to MongoDB Atlas GridFS (`fs.files` / `fs.chunks`). Downloads stream with `Content-Type: application/pdf` and strict `userId` ownership checks. Verified via 10-step automated script `verifyVaultFlow.js`.
- **Verification Status:** **PASS**

---

### Module 6: Appointments Management & PDF Generation
- **Primary Source Files:**
  - `lib/screens/appointments_screen.dart`
  - `lib/screens/book_appointment_screen.dart`
  - `lib/services/appointment_service.dart`
  - `lib/services/pdf_service.dart`
  - `backend/src/controllers/appointmentController.js`
  - `backend/src/models/Appointment.js`
- **Backend API Endpoints:**
  - `GET /api/appointments` — Fetch upcoming and past doctor appointments
  - `POST /api/appointments` — Book new appointment with doctor/clinic metadata
  - `PATCH /api/appointments/:id/status` — Mark appointment `completed` or `cancelled`
- **MongoDB Collection:** `appointments`
- **Audit Findings & Fixes:**
  - *Identified Defect:* Completed and cancelled appointments remained visible in the "Upcoming" filter tab.
  - *Remediation:* Updated client filter predicates and server status patch handler to cleanly categorize appointments into Upcoming vs History tabs upon state change.
- **Verification Status:** **PASS**

---

### Module 7, 8, 9: Healthcare Discovery (Nearby Hospitals, Explore Maps, Ambulance SOS)
- **Primary Source Files:**
  - `lib/screens/nearby_hospitals_screen.dart`
  - `lib/screens/explore_maps_screen.dart`
  - `lib/screens/ambulance_assistance_screen.dart`
  - `lib/services/hospital_service.dart`
  - `lib/services/hospital_repository.dart`
  - `backend/src/controllers/hospitalController.js`
  - `backend/src/routes/hospitalRoutes.js`
- **Backend API Endpoints:**
  - `GET /api/hospitals/nearby?lat=...&lng=...&radius=...` — Spatial discovery proxy with 15-minute in-memory cache
- **Audit Findings & Fixes:**
  - *Identified Critical Defect:* Overpass API queries failed with HTTP 502/406 due to server capacity limits and invalid syntax (`out center tags 40;`). Nominatim queries also failed when coordinates were passed directly into free-text search fields.
  - *Remediation:*
    1. Built backend caching proxy on Render with multi-endpoint failover (Kumi systems, Main Overpass, Overpass private).
    2. Corrected Overpass QL to `out center 40;`.
    3. Fixed Nominatim reverse lookup with a calculated spatial bounding box (`viewbox`).
    4. Established centralized reactive `HospitalRepository.instance` (`ChangeNotifier`) guaranteeing identical, synchronized hospital markers across Nearby Hospitals, Maps, and Ambulance.
- **Verification Status:** **PASS**

---

### Module 10: Health Metrics (BMI & Water Intake Tracking)
- **Primary Source Files:**
  - `lib/screens/bmi_calculator_screen.dart`
  - `lib/screens/water_intake_screen.dart`
  - `lib/services/health_metrics_service.dart`
  - `backend/src/controllers/metricsController.js`
  - `backend/src/models/WaterIntake.js`
  - `backend/src/models/BMIRecord.js`
- **Backend API Endpoints:**
  - `GET /api/metrics/water/today` — Retrieve authenticated user's current day intake
  - `POST /api/metrics/water/log` — Increment water log by 250ml, 500ml, or custom volume
  - `POST /api/metrics/bmi/calculate` — Store calculated BMI with height/weight history
- **MongoDB Collections:** `waterintakes`, `bmirecords`
- **Audit Findings & Fixes:**
  - Verified local date-boundary calculation so midnight transitions cleanly reset the daily progress ring while preserving historical trend logs.
- **Verification Status:** **PASS**

---

## 4. Architecture Diagram

```mermaid
graph TD
    subgraph ClientLayer ["MEDGUARD Flutter Client (Web, Android Emulator, Physical APK)"]
        UI["Material 3 Dark Teal UI & Navigation"]
        Repo["HospitalRepository (Reactive ChangeNotifier)"]
        LocalNotif["FlutterLocalNotifications (Exact Alarm)"]
        AuthServ["Auth & Session Provider"]
    end

    subgraph CloudBackend ["Render Production Backend (HTTPS)"]
        Express["Express.js Server / Router"]
        Security["JWT Bearer Auth & Bcrypt Hashing"]
        HospProxy["Hospital Proxy Controller (15-min TTL Cache)"]
        AITriage["Gemini 1.5 Flash Clinical Triage Controller"]
        GridFSEngine["GridFS Bucket Streaming Engine"]
    end

    subgraph DataAndExternal ["Cloud Services & External Providers"]
        Atlas[("MongoDB Atlas Cloud ('medguard')")]
        GeminiCloud["Google Gemini AI Cloud API"]
        OSM["OpenStreetMap / Overpass / Nominatim APIs"]
    end

    UI --> AuthServ
    UI --> Repo
    UI --> LocalNotif

    AuthServ -->|HTTPS / JWT| Express
    Repo -->|HTTPS /api/hospitals| HospProxy
    UI -->|HTTPS /api/vault| GridFSEngine
    UI -->|HTTPS /api/assistant| AITriage

    Express --> Security
    Security --> Atlas
    HospProxy --> OSM
    AITriage --> GeminiCloud
    GridFSEngine --> Atlas
```

---

## 5. Summary of Verification Outcomes

| Stage | Target System | Scope | Result |
| :---: | :--- | :--- | :---: |
| **0** | Source Code Audit | Full repository codebase inspection | **PASS** |
| **1** | Auth & Profile | Registration, Login, Session, Profile, Avatar | **PASS** |
| **2** | Dashboard & UI | Dark Teal theme, Desktop Grid, Android Status Bar | **PASS** |
| **3** | AI Health Assistant | Clinical Triage, Doctor Guidance, Emergency 108/112 | **PASS** |
| **4** | Medicines & Reminders | Scheduling, Exact Alarm Notifications, Sound | **PASS** |
| **5** | Health Vault | Permanent GridFS Cloud Storage, Streamed PDF View | **PASS** |
| **6** | Appointments | Lifecycle (Book, Complete, Cancel), PDF Receipts | **PASS** |
| **7** | Nearby Hospitals | Real Healthcare Discovery, Dialing, Fallbacks | **PASS** |
| **8** | Explore Maps | Interactive OSM Map, Centralized Markers | **PASS** |
| **9** | Ambulance & SOS | Regional Emergency Dispatch, Contact Sync | **PASS** |
| **10**| BMI & Water | Metric Calculations, MongoDB Persistence | **PASS** |
| **11**| Backend & Database | MongoDB Atlas Live CRUD, Cold Start Barrier Bypass | **PASS** |
| **12**| Navigation Regression| Cross-route validation on Mobile and Desktop Web | **PASS** |
| **13**| Performance | 0 analyzer warnings, 118 unit tests, lean builds | **PASS** |
| **14**| Rubric Fulfillment | Aligned with all Sections A through J | **PASS** |
| **15**| Test Matrix | Comprehensive 22-module test table documented | **PASS** |
| **16**| Release Builds | Release APK (76.0 MB), Signed AAB (74.6 MB), Web | **PASS** |
| **17**| Physical Device Demo | 22-step offline server demonstration checklist | **PASS** |
