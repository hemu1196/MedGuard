# MEDGUARD — Android & Flutter Web Compatibility Matrix

## Platform Overview
MEDGUARD is engineered to operate seamlessly across three primary deployment targets:
1. **Physical Android Device (ARM64)**
2. **Android Emulator (x86_64 / ARM64)**
3. **Flutter Web (Modern Browsers: Chrome, Firefox, Safari, Edge)**

---

## Detailed Compatibility Matrix

| Feature | Physical Android | Android Emulator | Flutter Web | Fallback / Adaptation Strategy |
|---|---|---|---|---|
| **1. Medicine Alarms** | Exact alarms via `AlarmManager` with sound/vibration | Exact alarms via `AlarmManager` | Browser timer while tab is open | Native Android channels vs. in-memory Web timers |
| **2. Medicine Pop-up** | Full-screen interactive popup | Full-screen interactive popup | Full-screen modal on active route | Reactive stream triggers `MedicineReminderDialog` on all platforms |
| **3. Health Vault PDF** | PDF render, download, native share sheet | PDF render, download, share | Native browser PDF viewer, print/download dialog | `Printing.layoutPdf` provides seamless cross-platform preview |
| **4. Appointment PDF** | Branded A4 PDF slip, download & share | Branded A4 PDF slip | Print & download dialog | Uses PDF 1.4 core standard with ASCII fonts |
| **5. Doctor Calling** | Native telephony dialer (`tel:`) | Android emulator dialer | Browser `tel:` protocol handler | Phone validation ensures only valid numbers are sent |
| **6. Hospital Calling** | Native dialer (`tel:`) | Android emulator dialer | Browser `tel:` protocol handler | Missing phone numbers disable button gracefully |
| **7. Map Marker Call** | Direct marker call | Direct marker call | Direct marker call | Standardized `url_launcher` handling |
| **8. BMI & Water Intake** | Full dashboard & history | Full dashboard & history | Full dashboard & history | Responsive UI scales across phone and desktop viewports |
| **9. Clinician Limit** | Full override & dialog | Full override & dialog | Full override & dialog | Clinician restriction overrides generic formulas universally |
| **10. Voice SOS (Mic)** | Real hardware mic speech recognition | Emulated audio input or test trigger | Web Speech API or test trigger | "Test Trigger Keyword" button enables immediate evaluation on all platforms |
| **11. 5s Countdown** | Heavy haptic vibration + audio tick | Audio tick | Visual pulsing countdown | Haptic calls wrapped safely in try/catch |
| **12. Emergency SMS** | Opens native SMS composer with GPS link | Opens emulator SMS app with GPS link | Prepares payload, copies to clipboard, opens `sms:` | Multi-mode payload presentation modal with copy option |
| **13. MongoDB Atlas** | Direct REST synchronization | Direct REST synchronization | Direct REST synchronization | Centralized `ApiClient` with automated JWT injection |
| **14. Offline Cache** | SQLite (`sqflite`) | SQLite (`sqflite`) | `SharedPreferences` (LocalStorage) | Conditional storage backend via `kIsWeb` check |
