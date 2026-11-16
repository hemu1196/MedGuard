# MEDGUARD

Flutter health management and emergency assistance app with a Node.js / Express API and MongoDB Atlas storage.

## Features

- Account registration, login, profile and avatar management.
- Medicines, reminders, stock tracking and dose history.
- Appointments and PDF summaries.
- Private health documents stored in MongoDB GridFS.
- Water intake, BMI history and health dashboards.
- Hospital discovery and maps using OpenStreetMap services.
- AI assistance through the backend, with local fallbacks.
- Emergency contacts, GPS message preparation, voice SOS and opt-in fall detection with a cancellable countdown.

SOS opens the device's SMS composer. The user must confirm sending; the app does not verify delivery. Sensor monitoring runs while the app is active, and Web cannot provide native background alarms or fall sensing.

## Local setup

Use Flutter with Dart 3.12.2 or later, Node.js 22 or later, and an Android SDK for Android builds.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:5001
```

For an Android emulator use `http://10.0.2.2:5001`; for a physical device use your computer's reachable LAN address. The default API URL is the existing Render deployment. Local code changes do not update that deployment.

```sh
cd backend
cp .env.example .env
# Fill in MongoDB credentials and a randomly generated JWT_SECRET.
npm ci
npm start
```

The backend refuses to start without a JWT secret of at least 32 characters. Never reuse the former committed secret. Set `CORS_ORIGINS` to a comma-separated list of deployed Web origins. Localhost and existing LAN development origins are allowed by default.

Password recovery requires `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD` and `MAIL_FROM`. Without email configuration the API returns an explicit unavailable response. Recovery codes are random, stored only as hashes, expire after 15 minutes and can be used once. Changing or resetting a password revokes existing MongoDB sessions.

Legacy Firebase migration verifies a Firebase ID token on the server and requires a verified email. `FIREBASE_PROJECT_ID` defaults to this app's existing Firebase project. Client-supplied email, UID and password are not sufficient identity proof.

## Verification

```sh
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
cd backend
npm test
npm audit
```

The backend suite starts a disposable **local** MongoDB instance and tests the real HTTP API and GridFS. Install `mongod` and put it on PATH, or set `MONGOD_BIN` to its absolute path. These tests do not use the Atlas database or send real emails. Optional legacy Atlas checks remain under `backend/scripts`; `npm run test:atlas` writes and removes a temporary verification document in the configured Atlas database.

The Android release configuration currently uses a debug signing key for local installation. Configure a private release keystore before store distribution. A successful build does not establish physical-device behavior for SMS, GPS, microphone, alarms or fall sensing.

See [the November 2026 verification report](docs/MEDGUARD_2026_11_16_VERIFICATION.md) for changes, evidence and remaining deployment requirements. Older reports describe earlier snapshots and do not certify the current deployment.

## Main API routes

| Route | Purpose |
| --- | --- |
| `/api/health`, `/api/health/ready` | Database health and readiness |
| `/api/auth/register`, `/api/auth/login` | Account authentication |
| `/api/auth/request-password-reset`, `/api/auth/reset-password` | Emailed recovery code and confirmation |
| `/api/auth/change-password` | Authenticated change with current password |
| `/api/auth/firebase-migrate` | Verified Firebase identity migration |
| `/api/auth/refresh`, `/api/auth/logout` | Session renewal and revocation |
| `/api/users/me` | Profile and avatar management |
| `/api/medicines`, `/api/medicines/log` | Medicines and dose history |
| `/api/health-records`, `/api/health-records/upload` | Owner-scoped health vault |
| `/api/health-records/:recordId/download` | Authenticated private document download |
| `/api/appointments`, `/api/appointments/:appointmentId/pdf` | Appointments and private summaries |
| `/api/emergency/contacts`, `/api/emergency/sos/trigger` | Contacts and SOS event logging |
| `/api/wellness/water`, `/api/wellness/bmi` | Health metrics |
| `/api/hospitals/nearby` | Public facility discovery |
| `/api/ai/chat` | Authenticated AI proxy |

Most data routes require an active JWT session and scope records to their owner. Avatars remain public to support existing image rendering. Medical documents are not publicly served through `/uploads`.

## Security and rollout

The November review found live database and JWT credentials in tracked files. Their values were removed from the current source, but older Git history retains them. **Rotate the Atlas database password and hosting JWT secret before rollout**, update local and hosting environment values, and invalidate old sessions. Do not copy credentials from earlier documentation.

Deploy the backend security changes together with the updated client. Configure email and Web origins, then test recovery mail delivery and Firebase migration with a verified account. Run the real-device checklist before relying on emergency features.

Project: [hemu1196/MedGuard](https://github.com/hemu1196/MedGuard). License: [MIT](LICENSE).
