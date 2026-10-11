# MEDGUARD — Known Technical Limitations & Operational Constraints

## Academic Transparency Statement
In adherence to academic integrity and engineering best practices, this document details the intentional design boundaries, operating-system constraints, and platform-specific behaviors in MEDGUARD.

---

## 1. Operating System Permission Boundaries

### Background Microphone Listening
- Modern Android (API 29+) and iOS enforce strict security sandboxing that prevents continuous background microphone capture without a foreground service notification or explicit wake lock to protect user privacy.
- In MEDGUARD, **Voice SOS operates on-demand** when the user initiates voice monitoring or when the application is active, compliant with Google Play safety policies.

### Direct Background SMS vs. SMS Composer
- Direct silent SMS dispatch without user confirmation (`SmsManager.sendTextMessage`) is restricted by Google Play permissions policy (`SEND_SMS` requires default SMS handler status or special accessibility clearance).
- MEDGUARD employs **Method A (User-Authoritative SMS Composer Handoff)** via `url_launcher` (`sms:$phone?body=$message`), pre-filling the verified location payload for instantaneous transmission while maintaining complete store policy compliance and user consent.
- Concurrently, **Method B (Server-Authoritative Emergency Event Logging)** logs the emergency incident, timestamp, and GPS coordinates to the MongoDB Atlas backend cluster (`emergencyevents`).

---

## 2. Platform-Specific Variations

### Flutter Web Considerations
1. **Local Push Alarms:** Flutter Web lacks native Android AlarmManager integration. Exact scheduled notifications on Web utilize in-memory timers while the browser tab remains active.
2. **Telephony & SMS:** On desktop web browsers, clicking phone or SMS links initiates the OS default protocol handler (e.g., FaceTime, Skype, or default messaging app). A convenient "Copy Message" button is provided to support manual transfer.
3. **Web Speech Recognition:** Speech-to-Text in browsers is contingent on browser vendor support (e.g. Chrome Web Speech API). For browsers or environments lacking microphone support, MEDGUARD provides an on-screen **"Test Trigger Keyword"** simulation button.

### OpenStreetMap (OSM) Public Metadata Completeness
- Hospital telephone numbers are retrieved dynamically from live OpenStreetMap Overpass servers.
- While metropolitan facilities in major cities typically catalog verified telephone numbers, some rural or informal healthcare centers in the public OSM database may not have a registered telephone number.
- In such instances, MEDGUARD transparently displays **"Phone Unavailable"** and disables the call button rather than injecting fake or fabricated numbers.

---

## 3. MongoDB Atlas Network Requirements
- Connecting to MongoDB Atlas requires outbound network access on port `27017` and an active entry on the MongoDB Atlas IP Access List for the client machine.
- Local fallback caching using SQLite (Android) and SharedPreferences (Web) ensures offline functionality if internet connectivity is temporarily interrupted.
