# MEDGUARD — Node.js & MongoDB Atlas Backend Migration Plan

## Executive Summary
This document details the architectural migration plan for transitioning the **MEDGUARD** Smart Emergency Assistance & Health Management System from a hybrid Firebase prototype to a production-grade, self-hosted Node.js (Express 5) + Mongoose 9 + MongoDB Atlas backend.

---

## 1. Objectives & Requirements
- **Data Persistence**: Fully replace Cloud Firestore with MongoDB Atlas cluster (`medguardcluster.maylg97.mongodb.net`, database `medguard`).
- **Security & TLS**: Retain full TLS certificate verification (`rejectUnauthorized: true`), IPv4 DNS resolution stack (`family: 4` in Mongoose config) to eliminate macOS local dual-stack network TLS alert 80 issues.
- **Authentication**: JWT authentication with bcrypt password hashing; complete migration away from Firebase Auth while maintaining backward compatibility/linking for legacy records.
- **File Management & Vault**: Native Node.js `multer` disk storage service for Health Vault document uploads (lab reports, prescriptions, scans) and automated PDF summary generation.
- **Feature Continuity**: Zero disruption to core modules (Medicines, Appointments, Health Vault, Nearby Hospitals, Maps, Water Intake, BMI, Emergency Contact & Voice/Manual SOS).

---

## 2. System Architecture

```
+-------------------------------------------------------------+
|                     FLUTTER FRONTEND                        |
|  (Web / Android Emulator / Physical Android Device)         |
+------------------------------+------------------------------+
                               |
                        ApiClient (HTTP/JSON)
                               |
                               v
+-------------------------------------------------------------+
|                  EXPRESS 5 BACKEND API (5001)               |
|  - Auth Routes        (/api/auth)                           |
|  - Medicines Routes   (/api/medicines)                      |
|  - Health Vault       (/api/health-records)                 |
|  - Appointments       (/api/appointments)                   |
|  - Emergency & SOS    (/api/emergency)                      |
|  - Wellness           (/api/wellness)                       |
|  - AI Assistant       (/api/ai)                             |
+------------------------------+------------------------------+
                               |
                      Mongoose 9 Driver (TLS)
                               |
                               v
+-------------------------------------------------------------+
|                   MONGODB ATLAS CLUSTER                     |
|  - medguard Database (12 Collections)                        |
+-------------------------------------------------------------+
```

---

## 3. Migration Strategy & Safety Checkpoints

1. **Safety Checkpoint Branch**: Git branch `feature/mongodb-full-migration`.
2. **Dual Layer Repository Design**: Flutter repositories fall back gracefully to local SQLite/SharedPreferences if offline or if backend service is unreachable.
3. **Automated PDF Service**: PDFKit service in backend auto-compiles appointment summaries upon booking.
4. **Environment Isolation**: Production config stored in `backend/.env` with strict git exclusion (`.gitignore`).
