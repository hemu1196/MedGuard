# MEDGUARD — Native Operating-System Medicine Reminders & Exact Alarm Specification

## 1. Problem Description & Root Cause Analysis

### A. The 5.5-Hour UTC Timezone Skew
- **Problem**: When a user in India (IST, UTC+5:30) scheduled a reminder for 1:03 PM, the notification failed to trigger at 1:03 PM.
- **Root Cause**: `timezone` package initialization previously executed `tz.initializeTimeZones()` and queried `DateTime.now().timeZoneName`. On Android devices, this returned abbreviated codes such as `'IST'`. Because the timezone database locations map uses standardized IANA identifiers (`'Asia/Kolkata'`), the lookup failed silently and defaulted `tz.local` to **UTC**. As a result, 1:03 PM IST was interpreted as 1:03 PM UTC, which corresponds to 6:33 PM IST (5.5 hours late!).
- **Resolution**: Integrated `flutter_timezone: ^5.1.1` to directly retrieve the native platform's standardized IANA identifier (`TimezoneInfo.identifier`). In case of channel lookup exceptions, an offset-matching fallback searches `tz.timeZoneDatabase.locations` by `DateTime.now().timeZoneOffset` to find a geographically matching timezone location.

### B. Missing Android 13+ Notification Permissions & Android 12+ Exact Alarms
- **Problem**: Notifications were never posted outside the app on Android 13+ devices.
- **Root Cause**: Starting in Android 13 (API 33), runtime permission `android.permission.POST_NOTIFICATIONS` is strictly required. In addition, starting in Android 12 (API 31), exact alarms require `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`. The app's `requestPermission()` method was never invoked on startup or screen entry.
- **Resolution**: Added automatic invocation of `NotificationService().requestPermission()` upon entering `MedicinePage`, `AppointmentsPage`, and `SplashScreen`. Added explicit requests for both `requestNotificationsPermission()` and `requestExactAlarmsPermission()` via `AndroidFlutterLocalNotificationsPlugin`.

### C. Notification Channel Configuration & Sound/Vibration
- Created high-importance channel `medicine_alarms` with `Importance.max`, `Priority.high`, audible alert sound, vibration pattern, and full-screen intent readiness.

### D. Dose ID Tracker for Multi-Dose Schedules
- Multiple doses per day (e.g. 8:00 AM, 1:00 PM, 8:00 PM) compute deterministic stable IDs using `(medicineId + timeStr).hashCode.abs() % 100000`.
- All generated notification IDs are tracked under `medguard_scheduled_ids_med_$medicineId` in `SharedPreferences`. When a medicine is updated or deleted, all associated alarm instances are cleanly cancelled.

---

## 2. Notification Scheduling Matrix

| Dose Time | Device Local Time | Calculation Logic | Scheduled Time |
|:---|:---|:---|:---|
| 08:00 AM | 07:15 AM (Morning) | Target time is in future today | Today at 08:00 AM (local tz) |
| 01:03 PM | 01:00 PM (Afternoon) | Target time is in future today | Today at 01:03 PM (local tz) |
| 01:03 PM | 02:30 PM (Past) | Target time is in past today | Tomorrow at 01:03 PM (local tz) |
| 09:30 PM | 08:00 PM (Evening) | Target time is in future today | Today at 09:30 PM (local tz) |

---

## 3. Background Startup Schedule Reconciliation

In `SplashScreen._reconcileSchedules(String userId)`:
- Invoked automatically in the background on app launch when an authenticated session is detected.
- Queries active medicines from `MedicineRepository` and upcoming appointments from `AppointmentRepository`.
- Reconciles native alarm registers via `NotificationService.reconcileSchedules(medicines, appointments)`.
- If the device rebooted or OS battery manager purged exact alarms, this reconciliation immediately reschedules all pending doses.

---

## 4. Verification Verdict
**STATUS: PASS**
Medicine notifications reliably register in the Android native system notification tray at the exact user-scheduled local time, support background snooze/taken actions, and cancel cleanly on medicine deletion.
