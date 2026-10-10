# MEDGUARD — EXISTING FEATURE AUDIT & ARCHITECTURE MAPPING

**Date**: October 11, 2026  
**Project**: MEDGUARD — Smart Emergency Assistance & Health Management System  
**Repository Roots**:
- Flutter Frontend: `/Users/hemachandra/Mobile_App_Dev/med_ai`
- Node.js Backend: `/Users/hemachandra/Mobile_App_Dev/med_ai/backend`

---

## 1. Executive Overview

This audit establishes the baseline feature inventory, component mapping, data dependencies, and migration strategy from legacy Firebase services to the unified Node.js / Express 5 + Mongoose 9 / MongoDB Atlas backend.

---

## 2. Feature Inventory & Data Mapping Matrix

| Feature | Screen / File Path | Current Data Source | Planned Data Source | Migration Requirements | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Authentication** | `lib/screens/auth/login_page.dart` | Firebase Auth | Node.js `/api/auth` + JWT | Migrate user auth credentials to MongoDB Atlas `users` & `user_sessions` | MIGRATING |
| **Profile Wizard** | `lib/screens/onboarding/health_profile_page.dart` | Firestore `users/{uid}` | Node.js `/api/profile` | Sync personal/health data to MongoDB `users` collection | MIGRATING |
| **Dashboard** | `lib/screens/dashboard/dashboard_page.dart` | Combined Repositories | Node.js API + Local Cache | Pull dynamic metrics from MongoDB & calculate BMI | ACTIVE |
| **Medicines** | `lib/screens/medicines/medicine_page.dart` | Firestore `users/{uid}/medicines` | Node.js `/api/medicines` | Persist medicine list, schedules, dosages, stock count to MongoDB `medicines` | MIGRATING |
| **Medication Logs** | `lib/screens/medicines/medicine_page.dart` | Local / Memory | Node.js `/api/medication-logs` | Record Taken/Skipped/Missed events & update stock in MongoDB | NEW / ENHANCING |
| **Appointments** | `lib/screens/addons/appointments_page.dart` | Firestore `users/{uid}/appointments` | Node.js `/api/appointments` | Persist appointment schedule & generate automatic summary PDF | MIGRATING |
| **Health Vault** | `lib/screens/vault/health_vault_page.dart` | Firebase Storage & Firestore | Node.js `/api/health-records` + Local Storage | Store file metadata in MongoDB `health_records`, serve downloads securely | MIGRATING |
| **Prescription OCR** | `lib/screens/prescription/prescription_scanner_page.dart` | Gemini Vision AI API | Gemini Vision via Node.js API | Process image bytes, extract medicines, confirm & save to MongoDB | ENHANCING |
| **Water Intake** | `lib/screens/wellness/water_intake_page.dart` | SQLite / SharedPreferences | Node.js `/api/water-intake` | Sync daily hydration entries & historical totals to MongoDB `water_intake` | MIGRATING |
| **BMI Tracker** | `lib/screens/dashboard/dashboard_page.dart` | Calculated local | Node.js `/api/bmi` | Save BMI calculation history (`height`, `weight`, `score`) to MongoDB `bmi_history` | MIGRATING |
| **Nearby Hospitals** | `lib/screens/hospitals/nearby_hospitals_page.dart` | OpenStreetMap Nominatim / Geolocator | Nominatim REST API + Node Cache | Fetch real hospitals, calculate distance, launch map route & telephone call | ACTIVE |
| **Explore Maps** | `lib/screens/maps/explore_map_page.dart` | OpenStreetMap / Geolocator | OpenStreetMap / Node API | Render markers, display hospital details, trigger external navigation & calling | ACTIVE |
| **Emergency SOS** | `lib/screens/emergency/emergency_sos_page.dart` | Geolocator / SMS intent | Node.js `/api/emergency-events` + Speech | Support manual & voice-triggered SOS ("HELP ME"), compose SMS with GPS link, log event | ENHANCING |
| **Emergency Contacts** | `lib/widgets/emergency_contact_dialog.dart` | Firestore `users/{uid}/emergency_contact` | Node.js `/api/emergency-contacts` | Single source of truth in MongoDB `emergency_contacts` | MIGRATING |
| **AI Assistant** | `lib/screens/ai/ai_assistant_page.dart` | Gemini API / Fallback Service | Node.js `/api/ai/chat` | Route AI health queries through backend, store chat history in MongoDB | ENHANCING |

---

## 3. Detailed Component & Dependency Map

```text
[Flutter UI Layer]
  ├── LoginPage / RegisterPage ──> AuthRepository ──────> NodeApiClient ──> POST /api/auth/login ──> MongoDB `users`
  ├── HealthProfilePage ───────> ProfileRepository ───> NodeApiClient ──> POST /api/profile ───> MongoDB `users`
  ├── MedicinePage ────────────> MedicineRepository ──> NodeApiClient ──> GET/POST /api/medicines ──> MongoDB `medicines`
  ├── AppointmentsPage ────────> AppointmentRepository> NodeApiClient ──> GET/POST /api/appointments > MongoDB `appointments`
  ├── HealthVaultPage ─────────> VaultRepository ─────> NodeApiClient ──> GET/POST /api/health-records > MongoDB `health_records`
  ├── NearbyHospitalsPage ─────> HospitalService ─────> Nominatim API ──> OpenStreetMap REST
  ├── EmergencySosPage ────────> EmergencyService ────> NodeApiClient ──> POST /api/emergency-events > MongoDB `emergency_events`
  └── WaterIntakePage ─────────> WaterRepository ─────> NodeApiClient ──> GET/POST /api/water-intake > MongoDB `water_intake`
```

---

## 4. Verification Checkpoint & Rollback Baseline

- **Branch Created**: `feature/mongodb-full-migration`
- **Baseline Commit**: Pushed baseline state before editing.
- **Rollback Guarantee**: Retains all Review-1 legacy Firebase repositories and local fallbacks intact until Phase 16 migration validation passes 100%.
