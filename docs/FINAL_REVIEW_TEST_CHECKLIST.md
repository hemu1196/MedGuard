# MEDGUARD — Final Review Demonstration & Testing Checklist

## Purpose
This checklist is intended for evaluators, examiners, and project reviewers during the live demonstration of MEDGUARD. Follow these steps to verify all seven features end-to-end.

---

## Pre-Requisites
1. **Start Backend Server**:
   ```bash
   cd /Users/hemachandra/Mobile_App_Dev/med_ai/backend
   node index.js
   ```
   *Verify output displays:* `MongoDB Connected: medguard` and `Server running on port 5001`.
2. **Launch Application**:
   - For Android Emulator / Device:
     ```bash
     flutter run -d <device_id>
     ```
   - For Web Browser:
     ```bash
     flutter run -d chrome
     ```

---

## Demonstration Checklist

### Step 1: Authentication & Health Profile Setup
- [ ] Log in with your registered account (or create a new test user).
- [ ] Navigate to **Profile** from the dashboard.
- [ ] Verify that Full Name, Age, Height (cm), and Weight (kg) are accurately displayed from MongoDB.
- [ ] Update height/weight and save; verify persistence across page reloads.

### Step 2: Personalized BMI & Hydration Dashboard (Feature 6)
- [ ] Open **Wellness / Water Intake** from the dashboard.
- [ ] Verify BMI calculation card displays your calculated BMI, category, and disclaimer.
- [ ] Check Hydration Guidance: observe baseline fluid target based on your weight and activity level.
- [ ] Switch activity chips (Sedentary -> Moderate -> Active); verify fluid recommendations adjust.
- [ ] Tap **Set Doctor Limit**: enter `1500 ml` and save; verify that the banner states **"Clinician Limit Active: 1500 ml"** and overrides general calculations.
- [ ] Log `+250 ml`; observe progress ring update. Tap **Undo** to revert the entry.

### Step 3: Real-Time Medicine Reminders with Popup & Snooze (Feature 1)
- [ ] Open **Medicines** from the bottom navigation.
- [ ] Tap **Add Medicine**: name a medication (e.g. "Amoxicillin 500mg"), choose a time, and save.
- [ ] Observe scheduled confirmation SnackBar.
- [ ] On the medicine card, tap **Test Reminder Now**.
- [ ] Verify immediate appearance of `MedicineReminderDialog` with sound and vibration.
- [ ] Tap **SNOOZE**: select `10 min`; verify scheduled confirmation.
- [ ] Retest and tap **TAKEN**: observe stock count decrement in real-time.

### Step 4: Health Vault PDF Generation, Download & Share (Feature 2)
- [ ] Open **Health Vault** from the bottom navigation.
- [ ] Tap any existing medical record (or add a new blood report).
- [ ] Tap the three dots menu on the card and select **Download PDF**.
- [ ] Verify the A4 document opens in print preview with title, doctor name, and formatted content.
- [ ] Select **Share PDF**; verify system share sheet opens.

### Step 5: Clinical Appointments, PDF Slip & Doctor Calling (Feature 3)
- [ ] Open **Appointments** from Add-ons.
- [ ] Add an appointment with a real doctor phone number (e.g. `+919876543210`).
- [ ] On the created appointment card, tap the **Phone Icon**: verify native dialer opens with pre-filled number.
- [ ] Tap **Download Summary PDF**: verify appointment confirmation slip generated.
- [ ] Tap **Share Summary PDF**: verify share sheet handoff.

### Step 6: Nearby Hospitals & Map Calling (Features 4 & 5)
- [ ] Open **Nearby Hospitals**.
- [ ] Change radius (5 km to 25 km); observe real OpenStreetMap facilities loading.
- [ ] Look at hospital cards:
  - If phone is present: button is labeled **"CALL HOSPITAL"**; tapping it opens phone dialer.
  - If phone is absent: button is disabled with label **"Phone Unavailable"**.
- [ ] Open **Explore Map**: tap a hospital marker; verify call button works from the bottom sheet.

### Step 7: Microphone Voice SOS with 5-Second Cancel Countdown (Feature 7)
- [ ] Open **Emergency SOS** from the bottom navigation.
- [ ] Ensure an emergency contact is saved with a valid phone number.
- [ ] Tap **🎙 Activate Voice SOS**.
- [ ] Grant microphone permission when prompted.
- [ ] Speak clearly: `"HELP ME"` or `"SOS"` (or tap **Test Trigger Keyword** in the sheet).
- [ ] Observe the **5-Second Cancel Countdown Dialog** appearing:
  - Pulsing red indicator counts down: 5... 4... 3... 2... 1.
  - Device vibrates with heavy haptic impact.
- [ ] **Test Cancellation**: On first try, tap **CANCEL SOS**; verify SnackBar confirms cancellation and no alert is sent.
- [ ] **Test Completion**: Retrigger and let countdown reach `0` (or tap **SEND IMMEDIATELY**):
  - Emergency event logged to MongoDB Atlas (`emergencyevents`).
  - SMS composer opens pre-filled with recipient phone and live Google Maps GPS location link.
- [ ] Test the big **TAP FOR SOS** button: confirm manual SOS triggers without requiring microphone.
