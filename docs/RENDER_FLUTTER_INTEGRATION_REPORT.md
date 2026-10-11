# MEDGUARD — Cloud Backend (Render) & Flutter Architecture Integration Report

## 1. Executive Summary

MEDGUARD (**Smart Emergency Assistance & Health Management System**) has completed its migration from a local developer environment to the permanent production cloud backend deployed at:

**Production Cloud URL:** `https://medguard-cqmw.onrender.com`  
**Database Cluster:** MongoDB Atlas (`MedGuardCluster`, database: `medguard`)  
**Frontend Architecture:** Flutter (Web, Android Emulator, Physical Android, Release APK)  
**Backend Architecture:** Node.js 24 + Express 5 + Mongoose 9 (JWT-authenticated REST API)

All client-side hardcoded references to `localhost:5001`, `localhost:5000`, and `10.0.2.2:5001` have been eradicated from production execution paths. The entire Flutter network layer now routes through a centralized compile-time and runtime configuration class (`ApiConfig`), targeting the live Render HTTPS backend by default across all platforms.

---

## 2. Root Cause Analysis: Localhost & ClientFailed to Fetch Failures

Prior builds displayed `ClientFailed to fetch` or connection errors due to three architectural flaws:

1. **Hardcoded Platform Resolution in `ApiClient`**:
   In `lib/core/api/api_client.dart`, `baseUrl` was conditionally evaluating:
   ```dart
   if (kIsWeb) return 'http://localhost:5001/api';
   if (Platform.isAndroid) return 'http://10.0.2.2:5001/api';
   ```
   When the Flutter Web application ran in the browser (e.g. `http://localhost:57624`) or on physical Android devices, requests to `http://localhost:5001` or `http://10.0.2.2:5001` failed with socket connection errors or `ClientFailed to fetch` whenever the developer's local Mac Node.js process was stopped.
2. **Premature Timeouts on Cold Starts**:
   Render Free instances spin down during periods of inactivity. A cold wake-up takes between 15 to 25 seconds. The previous `ApiClient` had a rigid 15-second timeout, causing premature cancellation and HTTP request aborts before Render could finish routing.
3. **CORS Preflight & Credential Alignment**:
   Browser environments require explicit HTTP 204 preflight responses with `Access-Control-Allow-Origin`, `Access-Control-Allow-Credentials: true`, and authorization header declarations.

---

## 3. Centralized API Architecture (`ApiConfig`)

A single, canonical configuration class was introduced in `lib/core/config/api_config.dart`:

```dart
class ApiConfig {
  ApiConfig._();

  static const String _defaultProdUrl = 'https://medguard-cqmw.onrender.com';

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultProdUrl,
  );

  /// Root URL of the target backend (trimmed, no trailing slash)
  static String get baseUrl {
    final raw = _configuredBaseUrl.trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Full API URL route prefix (/api)
  static String get apiUrl => '$baseUrl/api';

  /// Construct endpoint Uri for assets/uploads
  static Uri endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  /// Construct endpoint Uri for API routes
  static Uri apiEndpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiUrl$normalizedPath');
  }

  /// Checks if target is the live Render production cluster
  static bool get isProduction => baseUrl.contains('onrender.com');
}
```

### Integration with `ApiClient`
In `lib/core/api/api_client.dart`:
```dart
String get baseUrl {
  if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
    final trimmed = _customBaseUrl!.trim().replaceFirst(RegExp(r'/+$'), '');
    return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
  }
  return ApiConfig.apiUrl;
}
```
- **Web, Android Emulator, and Physical Android** all automatically use `https://medguard-cqmw.onrender.com/api`.
- **Local development** remains possible without modifying code using `--dart-define=API_BASE_URL=http://localhost:5001`.
- **Request timeouts** increased from 15s to 30s with bounded 503 retries (2.5s backoff) to comfortably absorb Render cold starts.

---

## 4. Subsystem Routing Matrix

| Feature Module | Endpoint Path | HTTP Method | Target Backend | Verified Live |
| :--- | :--- | :--- | :--- | :--- |
| **System Health** | `/api/health` | `GET` | Render | **PASS** |
| **Readiness Probe** | `/api/health/ready` | `GET` | Render | **PASS** |
| **User Registration** | `/api/auth/register` | `POST` | Render | **PASS** |
| **User Login** | `/api/auth/login` | `POST` | Render | **PASS** |
| **User Profile Save** | `/api/auth/profile` | `PUT` | Render | **PASS** |
| **User Profile Fetch** | `/api/users/me` | `GET` | Render | **PASS** |
| **Emergency Contacts** | `/api/emergency/contacts` | `GET`, `POST` | Render | **PASS** |
| **Set Primary Contact** | `/api/emergency/contacts/:id/primary` | `PATCH` | Render | **PASS** |
| **SOS Alert Logging** | `/api/emergency/sos/trigger` | `POST` | Render | **PASS** |
| **AI Assistant Chat** | `/api/ai/chat` | `POST` | Render (Server Gemini) | **PASS** |
| **Health Risk Vitals** | `/api/ai/risk-assessment` | `POST` | Render | **PASS** |
| **Medicines Tracking** | `/api/medicines` | `GET`, `POST` | Render | **PASS** |
| **Appointments** | `/api/appointments` | `GET`, `POST` | Render | **PASS** |
| **Health Vault Files** | `/api/health-records` | `GET`, `POST` | Render | **PASS** |
| **Water Intake** | `/api/wellness/water/today` | `GET`, `POST` | Render | **PASS** |
| **Nearby Hospitals** | OSM Overpass API | `GET` | Overpass Direct | **PASS** |
| **Cartography Tiles** | OpenStreetMap Tiles | `GET` | OSM Tile Servers | **PASS** |

---

## 5. Live Production Verification Evidence

1. **Readiness Probe**:
   ```bash
   curl -s https://medguard-cqmw.onrender.com/api/health/ready
   # Response:
   {"status":"ready","database":"connected","message":"MEDGUARD Backend and MongoDB Atlas are ready to serve requests."}
   ```
2. **CORS Preflight (Flutter Web Origin)**:
   ```bash
   curl -i -X OPTIONS https://medguard-cqmw.onrender.com/api/auth/login \
     -H "Origin: http://localhost:57624" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Authorization,Content-Type"
   # Response: HTTP/2 204 with Access-Control-Allow-Origin: http://localhost:57624
   ```
3. **End-to-End Registration & Profile Persistence**:
   - `POST /api/auth/register`: Successfully registered `render_test_123@example.com`, returned JWT `accessToken`.
   - `PUT /api/auth/profile`: Saved age 29, gender Male, blood group B+, height 175cm, weight 72kg, emergency contact Sarah Connor.
   - `GET /api/users/me`: Retrieved saved profile with 100% field parity.
   - `GET /api/emergency/contacts`: Retrieved automatically synthesized primary contact in MongoDB Atlas.

---

## 6. Commands for Development and Release Builds

### Development (Cloud Default)
```bash
flutter run -d chrome
flutter run -d <device_id>
```

### Explicit Localhost Development (Optional)
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5001
```

### Production Release Builds
```bash
flutter build web --release --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
flutter build apk --release --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
```
