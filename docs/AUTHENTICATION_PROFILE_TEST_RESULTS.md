# MEDGUARD — Authentication & Health Profile Persistence Test Results

## 1. Overview

This document presents the complete test results for user registration, login, JWT token issuance, session restoration, onboarding wizard profile completion, MongoDB Atlas persistence, and emergency contact synchronization using the live cloud backend (`https://medguard-cqmw.onrender.com`).

---

## 2. Authentication Test Matrix

| Test Case | Method & Route | Expected Behavior | Live Render Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **New User Registration** | `POST /api/auth/register` | Password hashed with bcrypt; user saved in MongoDB; valid JWT issued | Registered `render_test_123@example.com`; returned JWT token and user profile | **PASS** |
| **Duplicate Registration** | `POST /api/auth/register` | Reject with HTTP 400 "Email already registered" | Duplicate email rejected with HTTP 400 | **PASS** |
| **Invalid Email/Password** | `POST /api/auth/login` | Reject with HTTP 400/401 "Invalid email or password" | Rejected with `{"success":false,"message":"Invalid email or password."}` | **PASS** |
| **Valid Login** | `POST /api/auth/login` | Return authenticated session with JWT `accessToken` | Returned HTTP 200 with JWT and user profile | **PASS** |
| **Session Restoration** | `GET /api/users/me` | Return user profile when valid Bearer token attached | Returned saved user data and `profileCompleted: true` | **PASS** |
| **Unauthenticated Reject** | `GET /api/users/me` (No token) | Reject with HTTP 401 "Access token missing" | Rejected with HTTP 401 Unauthorized | **PASS** |
| **Expired Token Detection** | Client `isTokenExpired()` | Detect token expiration and require re-authentication | Verified in unit tests: detected expired timestamp | **PASS** |
| **Session Logout** | Client `clearStaleSession()` | Wipe cached token and SharedPreferences session | Tokens erased; user navigated to Login | **PASS** |

---

## 3. Health Profile Onboarding Persistence Test Matrix

The 4-step Health Profile Setup wizard (`HealthProfilePage`):
1. **Personal Information**: Full Name, Date of Birth / Age, Gender, Blood Group
2. **Health Metrics**: Height (cm), Weight (kg), Allergies, Chronic Conditions
3. **Emergency Contact**: Contact Name, Relationship, Phone Number
4. **Review & Confirm**: Summary display followed by "Complete Profile"

| Field | Input Test Value | Saved in MongoDB Atlas | Fetched from `/api/users/me` | Verified UI Match | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Full Name** | Cloud Test User | `fullName: "Cloud Test User"` | `Cloud Test User` | **MATCH** | **PASS** |
| **Age** | 29 | `age: 29` | `29` | **MATCH** | **PASS** |
| **Gender** | Male | `gender: "Male"` | `Male` | **MATCH** | **PASS** |
| **Blood Group** | B+ | `bloodGroup: "B+"` | `B+` | **MATCH** | **PASS** |
| **Height** | 175 cm | `heightCm: 175` | `175` | **MATCH** | **PASS** |
| **Weight** | 72 kg | `weightKg: 72` | `72` | **MATCH** | **PASS** |
| **Allergies** | Pollen | `allergies: ["Pollen"]` | `["Pollen"]` | **MATCH** | **PASS** |
| **Emergency Contact** | Sarah Connor | `emergencyContactName: "Sarah Connor"` | `Sarah Connor` | **MATCH** | **PASS** |
| **Emergency Phone** | +91 98450 11223 | `emergencyPhone: "+91 98450 11223"` | `+91 98450 11223` | **MATCH** | **PASS** |
| **Emergency Relationship**| Mother | `emergencyRelationship: "Mother"` | `Mother` | **MATCH** | **PASS** |
| **Profile Completed Flag**| true | `profileCompleted: true` | `true` | **MATCH** | **PASS** |

---

## 4. Emergency Contact Collection Auto-Sync Verification

When the profile was saved via `PUT /api/auth/profile`, the backend automatically upserted the primary emergency contact into the `emergency_contacts` collection:

```bash
curl -s -X GET https://medguard-cqmw.onrender.com/api/emergency/contacts \
  -H "Authorization: Bearer <valid_jwt_token>"
```

**Live Verification Output:**
```json
{
  "success": true,
  "contacts": [
    {
      "_id": "6acb7f81168a3b014de23084",
      "userId": "6acb7f75168a3b014de23079",
      "name": "Sarah Connor",
      "relation": "Mother",
      "phone": "+91 98450 11223",
      "isPrimary": true,
      "createdAt": "2026-10-11T12:22:25.922Z",
      "updatedAt": "2026-10-11T12:22:25.922Z"
    }
  ]
}
```

**Result:** The emergency contact entered during onboarding appears immediately on the Ambulance Assistance screen with a primary gold star badge without manual re-entry.
