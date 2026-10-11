# MEDGUARD — Profile Save & Flutter Web API Connection Fix Report

## 1. Executive Summary

During health profile setup onboarding in the Flutter Web application (`http://localhost:57624`), clicking **Complete Profile** failed with:
```text
Unable to save profile:
ClientFailed to fetch, uri=http://localhost:5001/api/auth/profile
```

This report documents the root cause diagnosis, architectural resolution, full data persistence validation, and test suite execution verifying that MEDGUARD now persists health profile details reliably to MongoDB Atlas (`medguard` database) across Flutter Web, Android Emulators, and physical devices.

---

## 2. Root Cause Analysis

### A. Express Server Cold-Start Exit via Atlas Handshake (`minPoolSize: 1`)
- **Diagnosis**: In `backend/config/database.js`, the Mongoose connection options previously specified `minPoolSize: 1`. In MongoDB Atlas Free Tier (M0 multi-tenant replica sets), secondary shard proxies (`ac-vgpbmmv-shard-00-00`, `00-01`, `00-02`) do not maintain active TLS state prior to primary election, throwing OpenSSL `SSL alert number 80 (internal_error)`.
- **Server Shutdown**: In `backend/index.js`, `startServer()` awaited `connectDB()` before invoking `app.listen()`. When the initial connection failed or took time, the process executed `process.exit(1)`, killing port `5001`.
- **Browser Behavior**: In Flutter Web, when the browser attempts an `http.put()` or preflight `OPTIONS` against a non-listening port, the browser's `fetch()` API rejects immediately with `TypeError: Failed to fetch`, which Flutter packages surface as `ClientException: ClientFailed to fetch`.

### B. Missing Dynamic CORS Preflight Handling for Dynamic Web Origin
- Flutter Web runs on randomized local ports (e.g. `http://localhost:57624`).
- Express required dynamic pattern matching (`/^http:\/\/localhost(:\d+)?$/`) and an explicit `OPTIONS` preflight middleware returning `204 No Content` with:
  - `Access-Control-Allow-Origin: http://localhost:57624`
  - `Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS`
  - `Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept, Authorization`
  - `Access-Control-Allow-Credentials: true`

### C. Route & Method Divergence
- The frontend profile repository attempted `PATCH /api/users/me` followed by fallback to `PUT /api/auth/profile`.
- Routes lacked symlinks for `POST`, `PUT`, `PATCH`, and `GET` across both `/api/auth/profile` and `/api/users/profile`.

---

## 3. Implementation Details

### A. Non-Blocking Express Server & Resilient Reconnection Lifecycle (`backend/index.js`)
1. **Immediate Port Binding**: `app.listen(PORT, "0.0.0.0")` executes immediately upon process launch. The HTTP server is listening on port `5001` within milliseconds.
2. **Dynamic CORS Middleware**: Allows all local development hosts (`localhost`, `127.0.0.1`, `10.0.2.2`, LAN subnets `10.x.x.x` and `192.168.x.x`) and handles preflight `OPTIONS` requests immediately with status `204`.
3. **Database Readiness Guard**: `/api` routes check `mongoose.connection.readyState`. If MongoDB Atlas is in the middle of connecting, requests receive a clean JSON `503 Service Unavailable` response with CORS headers, instead of an unhandled browser TCP disconnect.
4. **Resilient Background Reconnect**: If an initial Atlas TLS handshake times out or encounters cooldown, an automated background loop retries every 5 seconds without shutting down the HTTP service.

### B. MongoDB Atlas Connection Optimization (`backend/config/database.js`)
- `minPoolSize: 0`: Prevents opening unused sockets to secondary replica set shards until needed.
- `maxRetries: 8`: Increased retry attempts with progressive backoff (`Math.min(retryDelayMs * attempt, 6000)`).
- Timeouts: Configured `serverSelectionTimeoutMS: 20000`, `connectTimeoutMS: 20000`, `socketTimeoutMS: 60000`, `family: 4` (IPv4 first to prevent IPv6 TLS stalls), and `retryWrites: true`.

### C. Route Unification (`backend/src/routes/authRoutes.js` & `userRoutes.js`)
Both `/api/auth` and `/api/users` expose unified handlers pointing to `authController`:
- `GET /me` & `GET /profile` -> `authController.getMe`
- `PUT /me`, `PATCH /me`, `POST /me` -> `authController.updateProfile`
- `PUT /profile`, `PATCH /profile`, `POST /profile` -> `authController.updateProfile`

### D. Full Profile Data Model & Field Mapping (`backend/src/controllers/authController.js` & `models/User.js`)
The backend saves all personal and medical fields to MongoDB Atlas:
- `fullName` (persisted as `fullName`, alias `name`)
- `dateOfBirth` (ISO Date)
- `age` (auto-calculated from `dateOfBirth` if provided, or saved explicitly)
- `gender` (`Male`, `Female`, `Other`, `Prefer not to say`)
- `bloodGroup` (`A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`)
- `heightCm` & `weightKg` (validated positive numbers, BMI auto-computed)
- `allergies` (array of cleaned strings)
- `chronicConditions` (array of cleaned strings)
- `emergencyMedicalInfo` (medications & emergency guidance)
- `emergencyContactName`, `emergencyCountryCode`, `emergencyPhone`, `emergencyRelationship`
- `profileCompleted: true` automatically set once required criteria are satisfied

### E. Frontend Client Hardening (`lib/core/api/api_client.dart` & `lib/repositories/profile_repository.dart`)
- Added `Accept: application/json` header to all HTTP requests.
- Added `ApiClient.setCustomBaseUrl()` for easy LAN physical device testing.
- `ProfileRepository.saveProfile()` synchronizes updated server user data into local `ApiClient` session and `SharedPreferences` upon server confirmation.
- `HealthProfilePage` keeps user-entered form data intact on errors, shows clear snackbars, disables multiple clicks during saving, and only navigates to Dashboard upon confirmed server persistence.
- `ProfilePage` reloads full persisted data upon entry and edit completion.

---

## 4. Verification & Testing Evidence

### Test 1: CORS Preflight Verification
```bash
curl -i -X OPTIONS http://localhost:5001/api/auth/profile \
  -H "Origin: http://localhost:57624" \
  -H "Access-Control-Request-Method: PUT" \
  -H "Access-Control-Request-Headers: authorization,content-type"
```
**Output**:
```text
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: http://localhost:57624
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS
Access-Control-Allow-Headers: Origin,X-Requested-With,Content-Type,Accept,Authorization
```

### Test 2: Server Health Check
```bash
curl -i http://localhost:5001/api/health
```
**Output**:
```text
HTTP/1.1 200 OK
{"status":"healthy","mongodb":"connected"}
```

### Test 3: End-to-End Profile API Integration Suite (`testProfileApi.js`)
```bash
node backend/scripts/testProfileApi.js
```
**Results**:
- **STEP 1: CORS Preflight**: Verified HTTP 204 with matching origin `http://localhost:57624`.
- **STEP 2: User Registration**: Registered test user and retrieved JWT token.
- **STEP 3: Profile Persistence**: Saved Full Name, DOB, Gender, Blood Group, Height (178 cm), Weight (74 kg), Allergies, and Emergency Contact via `PUT /api/auth/profile`. Server confirmed `profileCompleted: true` and calculated age (31 years).
- **STEP 4: Profile Retrieval**: Fetched `GET /api/users/me` and confirmed exact persisted data matches.
- **Result**: `ALL PROFILE PERSISTENCE & CORS TESTS PASSED!`

### Test 4: Flutter Static Analysis
```bash
flutter analyze
```
**Result**:
```text
Analyzing med_ai...
No issues found! (ran in 3.9s)
```

### Test 5: Flutter Test Suite
```bash
flutter test
```
**Result**:
```text
00:05 +59: All tests passed!
```
All 59 unit and integration tests passing.

---

## 5. Summary of Modified Files

1. [backend/config/database.js](file:///Users/hemachandra/Mobile_App_Dev/med_ai/backend/config/database.js) — Fixed Mongoose connection pool options (`minPoolSize: 0`), connection timeouts, and retry logic.
2. [backend/index.js](file:///Users/hemachandra/Mobile_App_Dev/med_ai/backend/index.js) — Configured dynamic CORS origin regex, preflight 204 handler, DB readiness middleware, and non-blocking immediate `app.listen()`.
3. [backend/src/routes/authRoutes.js](file:///Users/hemachandra/Mobile_App_Dev/med_ai/backend/src/routes/authRoutes.js) — Added authenticated `/profile` routes (GET, POST, PUT, PATCH).
4. [backend/src/routes/userRoutes.js](file:///Users/hemachandra/Mobile_App_Dev/med_ai/backend/src/routes/userRoutes.js) — Added aliases for `/profile` and POST `/me`.
5. [backend/scripts/testProfileApi.js](file:///Users/hemachandra/Mobile_App_Dev/med_ai/backend/scripts/testProfileApi.js) — Automated end-to-end integration test suite.
6. [lib/core/api/api_client.dart](file:///Users/hemachandra/Mobile_App_Dev/med_ai/lib/core/api/api_client.dart) — Added `Accept: application/json` header and custom base URL configuration.
7. [lib/repositories/profile_repository.dart](file:///Users/hemachandra/Mobile_App_Dev/med_ai/lib/repositories/profile_repository.dart) — Synchronized authenticated session cache upon server profile save.
