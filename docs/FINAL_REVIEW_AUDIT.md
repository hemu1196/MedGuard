# MEDGUARD — Final Review Feature Audit & Implementation Plan

**Application:** MEDGUARD — Smart Emergency Assistance & Health Management System  
**Audit Date:** October 11, 2026  
**Auditor:** Lead Architect & Senior Engineering Team  
**Git Branch:** `feature/final-review-master`  
**Target Platforms:** Flutter Web, Android Emulator, Physical Android Device  
**Backend:** Node.js v24 + Express 5, MongoDB Atlas (`medguard` database)

---

## 1. Project Overview & Architectural Health

MEDGUARD is a comprehensive digital health and smart emergency assistance system built with Flutter and a decoupled Node.js/Express backend connecting to MongoDB Atlas.

### Current Milestone Assessment
- **Authentication & User Identity:** Fully migrated to MongoDB Atlas (`medguard.users`), JWT tokens persisted in `SharedPreferences`, server-authoritative profile completion verified.
- **Backend Architecture:** Express 5 on port `5001` with Mongoose 8.9. Models for `User`, `Medicine`, `MedicationLog`, `Appointment`, `HealthRecord`, `BmiHistory`, `WaterIntake`, `EmergencyContact`, `EmergencyEvent` exist.
- **Database Status:** Mongoose connects to MongoDB Atlas cluster `medguardcluster.maylg97.mongodb.net`. Intermittent TLS alert 80 errors occur on specific cluster shards when client IP `115.243.91.113` is subject to Atlas shard propagation delays. Raw queries and verified CRUD operations have been validated.
- **Static Analysis & Tests:** Flutter baseline has 0 analyze errors and 51 passing unit/widget tests.

---

## 2. Feature-by-Feature Audit & Gap Analysis

### Feature 1: Exact-Time Medicine Reminder with Sound, Popup and Snooze
- **Current State:**
  - `Medicine` model and `MedicineRepository` exist and store medicines in MongoDB (`medicines` collection).
  - `NotificationService.scheduleMedicineReminder()` erroneously called `_notificationsPlugin.show(...)` immediately instead of using timezone-aware `zonedSchedule`.
  - Missing exact alarm permissions (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS`) in `AndroidManifest.xml`.
  - No interactive actions (TAKEN, SNOOZE, SKIP, DISMISS) with stock deduction and adherence logging.
  - No foreground in-app popup dialog when MEDGUARD is open.
  - Flutter Web notifications were skipped (`if (kIsWeb) return;`).
- **Required Changes:**
  1. Add Android notification permissions, exact alarm declaration, and boot receiver in `AndroidManifest.xml`.
  2. Implement timezone initialization (`timezone` package with local timezone).
  3. Update `NotificationService` to support exact time scheduling, custom notification channel with sound & vibration, notification actions (Taken, Snooze, Skip).
  4. Implement in-app medicine alert dialog listener when app is foregrounded.
  5. Implement dose logging (`/api/medicines/log`) that deducts stock exactly once for 'taken' and records 'skipped'/'snoozed'.
  6. Add Web in-browser notification / in-app audio reminder strategy.
  7. Add "Test notification now" button in the Medicine UI.

### Feature 2: Health Vault PDF Download and Sharing
- **Current State:**
  - `HealthVaultPage` allows uploading records (images and PDF files) and viewing records.
  - Record cards lack "Download PDF", "Share", and "Convert image to PDF" actions.
  - Backend has `HealthRecord` model and `storageService.js` supporting uploads to `uploads/vault`.
- **Required Changes:**
  1. Add maintained `pdf`, `printing`, `share_plus` packages to `pubspec.yaml`.
  2. Implement PDF generation from image records ("Convert to PDF").
  3. Implement uncorrupted PDF file download on Android (via public download/documents directory) and Web (via browser blob anchor download).
  4. Implement system share sheet using `share_plus` (Android) and Web Share API / download fallback (Web).
  5. Secure backend download endpoint verifying ownership (`/api/health-records/:id/download`).

### Feature 3: Appointment PDF Generation, Download, Share and Doctor Call
- **Current State:**
  - `AppointmentsPage` has appointment booking and list view.
  - "Call Doctor" button merely showed a placeholder SnackBar (`'Calling ${appt.doctorName}: ${appt.phoneNumber}'`).
  - No PDF generation or download/share actions existed.
- **Required Changes:**
  1. Replace placeholder call SnackBar with genuine `url_launcher` phone dialer (`tel:$cleanPhone`) with phone number validation.
  2. Implement clean MEDGUARD-branded A4 PDF summary generation ("Personal Appointment Record") with unique reference, patient details, doctor, clinic, date/time, notes, and timestamp.
  3. Add "Download PDF" and "Share PDF" buttons on appointment detail cards.
  4. Ensure backend persistence to MongoDB `appointments` collection.

### Feature 4 & 5: Hospital Calling in Nearby Hospitals and Maps
- **Current State:**
  - `NearbyHospitalsPage` has `_makePhoneCall` with `tel:` URI.
  - `ExploreMapPage` has `_launchPhoneCall` with `tel:` URI.
  - However, if the hospital returned from OSM/Overpass lacks a phone number, the UI behavior is inconsistent between Maps and Nearby Hospitals.
- **Required Changes:**
  1. Unify normalized hospital calling helper across `NearbyHospitalsPage` and `ExploreMapPage`.
  2. When phone number is unavailable from provider, explicitly display "Phone number unavailable" and disable the Call button. Never fabricate or hardcode fake numbers.
  3. Verify `url_launcher` dialer handoff across Android and Web.

### Feature 6: Personalized BMI and Water-Intake Dashboard
- **Current State:**
  - `BmiCalculator` calculates BMI = weight / (height/100)^2 with adult categories and non-diagnostic disclaimers.
  - `WaterIntakePage` tracks daily water intake, allows quick-add presets, and resets today's water.
  - Lacks BMI integration directly on the hydration dashboard.
  - Lacks personalized hydration calculation based on age, weight, activity level, climate, and user goal.
  - Lacks strict prioritization of clinician-prescribed fluid restrictions.
  - Lacks single-entry undo/remove functionality.
- **Required Changes:**
  1. Integrate current user BMI and height/weight display into `WaterIntakePage`.
  2. Implement personalized hydration guidance engine taking into account:
     - Weight and age group
     - Activity level (Sedentary, Moderate, Active)
     - Climate / temperature context
     - User-selected goal
     - **Clinician-prescribed fluid limit taking strict precedence** over all general formulas.
  3. Add clear educational disclaimers (screening/informational only, beverage vs food water).
  4. Add single-entry undo/remove button to avoid wiping entire daily history.
  5. Ensure sync with MongoDB `bmi_history` and `water_intake` collections.

### Feature 7: Microphone Voice SOS and Automatic Emergency SMS
- **Current State:**
  - `EmergencySosPage` has a voice trigger button that calls `speech.listen()` on speech recognition.
  - However, it immediately opened a manual dialog on phrase match, lacking an automated cancel countdown.
  - No duplicate trigger blocking / debouncing.
  - Permissions were requested without clean handling of denied or permanently denied states.
- **Required Changes:**
  1. Add `RECORD_AUDIO` to `AndroidManifest.xml`.
  2. Add active listening pulse/indicator with clear user feedback.
  3. On distress phrase ("HELP ME", "EMERGENCY", "SOS"), trigger an immediate 5-second audible cancellation countdown modal.
  4. Method A (SMS Composer): If not canceled, fetch GPS coordinates, format Google Maps link, and open device SMS composer (`sms:$phone?body=...`) with primary contact prefilled.
  5. Method B (Optional Backend SMS): Add endpoint `/api/emergency/sos` on backend with idempotency, logging emergency event to MongoDB `emergencyevents`.
  6. Ensure manual SOS button works unconditionally without microphone or location permission.

---

## 3. Implementation Roadmap

1. **Phase 1: Dependencies & Android Permissions**
   - Add `pdf`, `printing`, `share_plus` to `pubspec.yaml`.
   - Update `AndroidManifest.xml` with notifications, exact alarms, boot receiver, and microphone permissions.
2. **Phase 2: Feature 1 (Exact-Time Medicine Reminder)**
   - Timezone initialization, exact scheduling, custom channel, notifications sound, interactive actions, in-app popup dialog, Web fallback.
3. **Phase 3: Feature 2 (Health Vault PDF Download & Sharing)**
   - PDF export for images, native download, share sheet, Web download fallback.
4. **Phase 4: Feature 3 (Appointment PDF Generation & Doctor Calling)**
   - Branded A4 appointment summary PDF generation, download, share, real phone dialer integration.
5. **Phase 5: Features 4 & 5 (Hospital Calling in Nearby & Maps)**
   - Unified calling helper, phone availability validation, disabled states when unavailable.
6. **Phase 6: Feature 6 (BMI & Personalized Hydration Dashboard)**
   - Multi-factor hydration calculator, clinician limit override, single-entry undo, BMI integration.
7. **Phase 7: Feature 7 (Microphone Voice SOS & SMS Workflow)**
   - Speech detection, 5-second cancel countdown, SMS composer dispatch, backend SOS logging.
8. **Phase 8: Persistence & Verification**
   - Backend routes, models, unit tests, `flutter analyze`, release builds.
