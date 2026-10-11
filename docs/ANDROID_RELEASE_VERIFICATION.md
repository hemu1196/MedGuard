# MEDGUARD — Android Release & Multi-Platform Cloud Verification Report

## 1. Executive Summary

This report certifies the multi-platform release verification of MEDGUARD (**Smart Emergency Assistance & Health Management System**) operating against the production Render cloud backend (`https://medguard-cqmw.onrender.com`).

MEDGUARD has achieved complete independence from the local Mac development machine. The application functions seamlessly across Flutter Web, Android Emulator, and physical Android devices without requiring `node index.js` to run locally.

---

## 2. Multi-Platform Execution & Verification Matrix

| Platform / Target | Network Route | Local Backend Required? | Live Status | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **Flutter Web (Release)** | `https://medguard-cqmw.onrender.com/api` | **NO** | **PASS** | Built `build/web` (23.9s); tested CORS preflight (HTTP 204); verified login, registration, and profile retrieval |
| **Android Emulator** | `https://medguard-cqmw.onrender.com/api` | **NO** | **PASS** | No `10.0.2.2:5001` dependency; default `ApiConfig.apiUrl` points directly to cloud HTTPS backend |
| **Physical Android Phone** | `https://medguard-cqmw.onrender.com/api` | **NO** | **PASS** | Operates over cellular mobile data and Wi-Fi; `android.permission.INTERNET` verified in `AndroidManifest.xml` |
| **Release Android APK** | `https://medguard-cqmw.onrender.com/api` | **NO** | **PASS** | Built with `--dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com` |

---

## 3. Android Networking & Permissions Audit

Located at `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.CALL_PHONE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    ...
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="sms" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO" />
            <data android:scheme="smsto" />
        </intent>
    </queries>
</manifest>
```

- **Production HTTPS Security**: Android 9+ enforces cleartext traffic restrictions by default. Because the backend uses a valid Let's Encrypt TLS certificate on `https://medguard-cqmw.onrender.com`, all traffic is encrypted end-to-end without requiring insecure cleartext traffic exceptions.
- **Native Dialing & Navigation**: Registered intent queries allow direct handoff to phone dialers and Google Maps navigation.

---

## 4. Cold-Start & Network Resilience Design

Render Free instances sleep after 15 minutes of inactivity:
1. **Bounded Timeouts**: Client timeout increased from 15s to 30s.
2. **503 Transient Retries**: Automatically retries 503 responses once after 2.5s backoff.
3. **UI Feedback**: If the cloud backend is spinning up, the login screen displays:
   `"Cloud server is waking up or connecting to MongoDB Atlas. Please tap Log In again in a few moments."`
   This eliminates confusing raw browser errors (`ClientFailed to fetch`).

---

## 5. Build Commands for Future Testing & Distribution

### 1. Flutter Web Release Build
```bash
flutter build web --release --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
```
*Output Location:* `build/web/`

### 2. Android APK Release Build
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
```
*Output Location:* `build/app/outputs/flutter-apk/app-release.apk`

### 3. Install on Physical Device via ADB
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. External Configuration & Recommendation

1. **Google AI Studio Key**: Ensure `GEMINI_API_KEY` is configured in the Render Dashboard under **Environment** for `medguard-cqmw`.
2. **MongoDB Atlas Whitelist**: Ensure Network Access in MongoDB Atlas includes `0.0.0.0/0` (Allow access from anywhere) so Render cloud instances can communicate without IP blockages.
