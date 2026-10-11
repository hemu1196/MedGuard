# MEDGUARD — Voice SOS & Emergency SMS Test Results

## 1. Scope of Verification
Verification of Feature 7 regarding voice-activated emergency assistance:
- Android runtime microphone permissions via `permission_handler`.
- Handling of permanent permission denial with device settings redirection.
- Continuous keyword listening with `speech_to_text`.
- Supported keywords: `"HELP ME"`, `"EMERGENCY"`, `"SOS"`.
- Prevention of duplicate/concurrent triggers.
- Active 5-second cancel countdown dialog with heavy vibration / haptic cues.
- SMS composer handoff with verified GPS coordinates link.
- Fallback simulation button for quiet environments, emulators, or web browsers.
- Unconditional manual SOS trigger.

---

## 2. Test Cases & Execution Results

| Test ID | Trigger Type | Action / Speech Input | Expected Output | Result |
|---|---|---|---|---|
| **VSOS-01** | First-Time Mic Request | User taps "🎙 Activate Voice SOS" | Requests `Permission.microphone`; upon grant, opens listening bottom sheet | **PASS** |
| **VSOS-02** | Permanent Denial | Mic permission marked "Don't ask again" | Displays explanatory dialog with "Open Settings" button (`openAppSettings()`) | **PASS** |
| **VSOS-03** | Keyword "HELP ME" Spoken | User speaks "Help me please" | Detects keyword; stops recognizer; launches `SosCountdownDialog` with 5s timer | **PASS** |
| **VSOS-04** | Keyword "EMERGENCY" Spoken | User speaks "This is an emergency" | Detects keyword; launches 5s countdown | **PASS** |
| **VSOS-05** | Keyword "SOS" Spoken | User speaks "SOS SOS" | Detects keyword; launches 5s countdown | **PASS** |
| **VSOS-06** | User Cancels Countdown | Taps "CANCEL SOS" during countdown | Cancels timer immediately; dismisses dialog; SnackBar shows "Voice SOS cancelled" | **PASS** |
| **VSOS-07** | Countdown Completes (0s) | Countdown reaches 0 | Closes dialog; obtains GPS coordinates; opens SMS composer; logs to MongoDB Atlas | **PASS** |
| **VSOS-08** | Send Immediately | User taps "SEND IMMEDIATELY" | Bypasses remaining seconds; dispatches emergency payload immediately | **PASS** |
| **VSOS-09** | Test Trigger Simulation | User taps "Test Trigger Keyword" in sheet | Immediately launches 5s countdown without speaking (ideal for testing & demos) | **PASS** |
| **VSOS-10** | Manual SOS Button | User taps massive red SOS circle | Works unconditionally without requiring microphone permissions | **PASS** |
| **VSOS-11** | No Contact Configured | Triggers SOS without configured contact | Displays "No Emergency Contact" dialog with "Add Contact" button | **PASS** |
