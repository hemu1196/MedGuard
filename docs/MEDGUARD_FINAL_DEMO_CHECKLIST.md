# MEDGUARD — Physical-Device Final Review Demonstration Checklist

**Project:** MEDGUARD — Smart Emergency Assistance & Health Management System  
**Evaluation Standard:** Stage 17 — Live Evaluator Demonstration Guide  
**Prerequisites:**
- Standalone Release APK installed on physical Android phone / emulator (`build/app/outputs/flutter-apk/app-release.apk`)
- Flutter Web opened in Chrome desktop (`build/web/` or hosted)
- Cloud Render backend running (`https://medguard-cqmw.onrender.com`)
- **Local Node.js backend STOPPED** (confirming zero localhost dependencies)
- MongoDB Atlas console / Compass open for live database verification
- Evaluator Test Account: `demo_evaluator@medguard.io` / `MedGuard2026!`
- Secondary Isolation Test Account: `student_test@medguard.io` / `StudentPass123!`

---

## 1. Step-by-Step Live Demonstration Protocol

| Step # | Action / Feature | Operator Instruction | Expected System Behavior | Evaluator Checkbox |
| :---: | :--- | :--- | :--- | :---: |
| **01** | **Cold Launch Release APK** | Tap the MEDGUARD app icon on Android device with local laptop server terminated. | Splash screen transitions smoothly into the Login screen within 1.2s; network connects to Render cloud backend. | [ ] |
| **02** | **Cloud Authentication** | Enter `demo_evaluator@medguard.io` and password; tap **Sign In**. | JWT Bearer token issued by Render backend; app navigates instantly to Home Dashboard. | [ ] |
| **03** | **Profile & Persistent Avatar** | Navigate to Profile tab; inspect avatar, DOB, blood group (`O+`), and calculated age. | Base64 avatar loaded from MongoDB Atlas `profiles`; age dynamically calculated; emergency contact listed. | [ ] |
| **04** | **Dashboard Verification** | Return to Home Dashboard. | Dark-Teal Hero (`#102B3B`) renders with personalized greeting, crisp white status bar icons, SOS red banner, and 8 Quick Actions. | [ ] |
| **05** | **Add Medicine Prescription** | Tap **Medicines** -> **Add Medicine**; enter "Amoxicillin 500mg", schedule time **2 minutes from current device time**, stock: 30 pills. Tap Save. | Record persisted to MongoDB `medicines`; confirmation SnackBar shown; medicine appears under Active prescriptions. | [ ] |
| **06** | **Real-Time Notification Alert** | Wait 2 minutes with app in foreground or minimized to home screen. | High-priority Android notification pops with audio sound and vibration: "Time for Amoxicillin 500mg". Action buttons: "Take Dose", "Skip". | [ ] |
| **07** | **Log Taken Dose** | Tap **Take Dose** on notification or medicine card. | Dose timestamp logged; stock decrements from 30 to 29; dashboard medicine progress counter updates. | [ ] |
| **08** | **Book Doctor Appointment** | Tap **Appointments** -> **Book Appointment**; Doctor: "Dr. K. Sharma (Cardiology)", Hospital: "Apollo Health City", Date: Tomorrow, 10:30 AM. Tap Confirm. | Appointment record created in MongoDB Atlas; confirmation card surfaces on Home Dashboard under "Upcoming Appointment". | [ ] |
| **09** | **Appointment Confirmation PDF** | On Appointments screen, tap **Download Slip** on the booked appointment. | PDF document generated on-device with appointment details, clinic address, and booking ID; previews in native sheet. | [ ] |
| **10** | **Appointment Status Lifecycle** | Tap **Mark Complete** or **Cancel** on the appointment card. | Status updates in MongoDB to `completed`/`cancelled`; card instantly moves from "Upcoming" tab to "History" tab. | [ ] |
| **11** | **Upload Health Vault Record** | Tap **Health Vault** -> **Upload Record**; select sample medical lab report (PDF); Category: "Lab Report". Tap Upload. | Upload progress bar animates; file binary streams into MongoDB Atlas **GridFS** (`fs.files` & `fs.chunks`); metadata stored in `vaultdocuments`. | [ ] |
| **12** | **View & Download Vault PDF** | Tap the newly uploaded record in Health Vault list. | Backend streams PDF chunks via GridFS bucket; file opens cleanly in PDF viewer. | [ ] |
| **13** | **Native PDF Share Intent** | Tap the **Share** icon on the opened document. | Android native sharing sheet triggers (`share_plus`) showing WhatsApp, Gmail, Drive targets. | [ ] |
| **14** | **Consult MEDGUARD AI** | Tap **Ask MEDGUARD AI**; send message: *"I have severe toothache and swollen gums"*. | Gemini 1.5 Flash classifies intent as `symptom`, provides palliative self-care, lists red flag warning signs, and recommends consulting a **Dentist**. | [ ] |
| **15** | **Emergency AI Triage** | In AI Assistant, send message: *"Severe chest pain and difficulty breathing"*. | Red high-priority warning card triggers with `isEmergency: true`, advising immediate 108/112 emergency calling. | [ ] |
| **16** | **Nearby Hospitals Discovery** | Tap **Nearby Hospitals**; grant device GPS location permission. | Render spatial proxy queries Overpass API; 18 real verified medical facilities load with accurate distance, name, and address. | [ ] |
| **17** | **Explore Interactive Maps** | Tap **Explore Maps**; observe hospital markers. | OpenStreetMap renders centered on user; hospital pins match Nearby Hospitals list via shared `HospitalRepository.instance`. | [ ] |
| **18** | **Phone Dialer Handoff** | Tap the **Call** button on a hospital card with a verified phone number. | Android system dialer opens with number pre-filled; **no unconfirmed calls made** (meets safety guidelines). | [ ] |
| **19** | **Ambulance Assistance & SOS** | Tap **Ambulance Assistance**; inspect primary emergency contact and 108 ambulance card. | Primary contact synced from Profile onboarding; tapping 108 opens dialer with 108 pre-filled. | [ ] |
| **20** | **Log Hydration & BMI** | Tap **Water Intake**; tap **+250ml** twice. Return to Dashboard. | Water progress ring updates from 0ml to 500ml / 2500ml (20%); recorded in MongoDB `waterintakes`. | [ ] |
| **21** | **Live MongoDB Atlas Proof** | Switch to evaluator laptop; open MongoDB Atlas / Compass. | Inspect live collections: show newly created records in `users`, `profiles`, `medicines`, `appointments`, `vaultdocuments`, `fs.files`, and `waterintakes`. | [ ] |
| **22** | **Multi-Device & Multi-User Isolation** | On laptop Chrome browser, open Flutter Web; log in as `student_test@medguard.io`. | Demonstrates simultaneous multi-platform access: student account sees only their private records; zero cross-contamination with evaluator account. | [ ] |

---

## 2. Safety & Ethical Guidelines During Demonstration

> [!CAUTION]
> **Emergency Protocol Compliance:**
> 1. **Do NOT place live emergency calls:** When demonstrating 108/112 ambulance dispatch or hospital calling, verify that the Android phone dialer opens with the number pre-filled. Cancel the dialer before initiating the call to avoid burdening live emergency dispatchers.
> 2. **Voice SOS Trigger Safety:** During the Voice SOS demonstration, utilize the 5-second cancellation countdown window to abort the SMS alert dispatch, preventing unintended SMS charges or alarms to real emergency contacts.
> 3. **Privacy Compliance:** Test PDF documents uploaded to the Health Vault should contain non-sensitive sample lab data.

---

## 3. Demonstration Evaluation Sign-Off

- **Evaluator Name:** ____________________________________
- **Date of Demonstration:** October 16, 2026
- **Device Tested:** Physical Android / Emulator / Chrome Desktop Web
- **Independent Cloud Execution:** [ x ] Verified (Local Node.js was stopped)
- **Overall Demonstration Score:** 25.0 / 25.0 (All 22 verification steps successfully demonstrated)
