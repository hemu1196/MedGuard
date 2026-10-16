# MEDGUARD — Appointment Reminders & Full CRUD Specification

## 1. Scope & Functional Requirements
The Doctor Appointments subsystem in MEDGUARD manages clinical consultations, doctor details, hospital locations, scheduled dates/times, native multi-reminder alarm triggers, consultation notes, status tracking, and printable PDF summaries.

---

## 2. Implemented Architecture & Fixes

### A. Dedicated Notification Channel & Timing Offsets
- Created `appointment_alarms` Android notification channel with `Importance.high` and audible alerts.
- Configured multi-reminder offsets:
  - 1 day before (1440 minutes)
  - 2 hours before (120 minutes)
  - 1 hour before (60 minutes)
  - 30 minutes before (30 minutes)
  - At appointment time (0 minutes)
- Reminders scheduled in the past are automatically filtered out.
- Each appointment tracks its scheduled notification IDs in `medguard_scheduled_ids_appt_$appointmentId` so that updating status to `Completed` or `Cancelled` cancels all alarms immediately.

### B. Full CRUD Operations & Stream-Based Reactivity
- **Create**: Saves to MongoDB Atlas via `POST /api/appointments`, receives canonical MongoDB `_id`, caches locally, broadcasts to UI stream, and schedules native system reminders.
- **Read**: Reactive `watchAppointments(userId)` emits local cache immediately, then syncs fresh data from MongoDB Atlas.
- **Update / Reschedule**: Updates date, time, notes, and doctor information via `PUT /api/appointments/:id`. Automatically cancels previous notification IDs and schedules new reminders.
- **Status Change**: Transitions between `Upcoming`, `Completed`, and `Cancelled` via `PATCH /api/appointments/:id/status`. Cancels alarms if no longer `Upcoming`.
- **Delete**: Cleans up both user-scoped and global local cache, deletes from MongoDB Atlas, and purges all scheduled notification alarms.
- **PDF Export**: Generates professional A4 summary with doctor name, facility, date/time, ref ID, and notes via `PdfExportService.generateAppointmentPdf`.

---

## 3. Verification & Test Matrix

| Operation | Test Method | Expected Behavior | Status |
|:---|:---|:---|:---:|
| Model Serialization | Unit test | `toMap()` and `fromMap()` preserve multi-reminders & notes | **PASS** |
| Fresh User Init | Unit test | Returns empty list without throwing errors | **PASS** |
| Save Appointment | Unit test | Returns valid appointment instance with canonical ID | **PASS** |
| Status Update | Unit test | Status toggles to `Completed`; alarm notifications cancelled | **PASS** |
| Delete Appointment | Unit test | Purges cache, updates broadcast stream to empty | **PASS** |
| PDF Summary | Integration test | Renders official appointment record with ref ID | **PASS** |

---

## 4. Verification Verdict
**STATUS: PASS**
Appointment reminders and CRUD functionality have been validated across all states and operations.
