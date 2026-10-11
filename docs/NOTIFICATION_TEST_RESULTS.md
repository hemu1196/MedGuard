# MEDGUARD — Medicine Notification & Snooze Verification Results

## 1. Scope of Verification
Verification of Feature 1 across foreground, background, device boot, and Web fallback execution modes:
- High-priority alarm channel initialization on Android.
- Exact time scheduling with the Android AlarmManager.
- Pop-up modal presentation when the application is active in the foreground.
- Action handlers for **TAKEN** (inventory reduction), **SNOOZE** (rescheduling), and **SKIP**.

---

## 2. Notification Channel Architecture
- **Channel ID:** `medicine_alarms`
- **Channel Name:** `Medicine Reminders`
- **Importance:** `Importance.max` / `Priority.high`
- **Audio:** System alarm sound enabled
- **Vibration:** Heavy alarm pattern `[0, 1000, 500, 1000]`
- **Category:** `AndroidNotificationCategory.alarm`
- **Permissions:** `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`

---

## 3. Test Cases & Execution Results

| Test ID | Scenario | Expected Behavior | Result |
|---|---|---|---|
| **NOTIF-01** | Add new medicine with reminder time | Exact alarm scheduled via `timezone` and `flutter_local_notifications`; SnackBar confirms scheduled time | **PASS** |
| **NOTIF-02** | Test Reminder Now triggered | Triggers `onMedicineAlert` broadcast stream; `MedicineReminderDialog` appears immediately | **PASS** |
| **NOTIF-03** | Confirm dose taken ("TAKEN") | Closes dialog, decrements stock count in MongoDB Atlas (`stockCount - 1`), updates dose history | **PASS** |
| **NOTIF-04** | Snooze dose for 10 minutes | Reschedules exact alarm for `DateTime.now() + 10min`; SnackBar confirms snooze time | **PASS** |
| **NOTIF-05** | Skip dose ("SKIP") | Logs skipped event, stock count remains unchanged | **PASS** |
| **NOTIF-06** | Flutter Web fallback | In-memory web timer fallback triggers alert when browser tab remains open | **PASS** |
| **NOTIF-07** | Device reboot | `RECEIVE_BOOT_COMPLETED` triggers broadcast receiver to re-register scheduled alarms | **PASS** |
