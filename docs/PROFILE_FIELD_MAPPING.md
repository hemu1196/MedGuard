# MEDGUARD Profile Field Mapping Specification

This document maps all user profile fields across the Flutter frontend UI, API request/response payloads, and MongoDB Atlas database schema (`medguard.users` collection).

| Flutter Field | API Property | MongoDB Schema Field | Type | Required | Validation Rule | Verified Status |
|---|---|---|---|---|---|---|
| Full Name | `fullName` / `name` | `fullName` | String | YES | Non-empty string | **PASS** |
| Date of Birth | `dateOfBirth` | `dateOfBirth` | Date (ISO8601) | YES | Valid past Date | **PASS** |
| Age | `age` | `age` | Number | YES | Calculated from DOB or >= 0 | **PASS** |
| Gender | `gender` | `gender` | String | YES | 'Male', 'Female', 'Other', 'Prefer not to say' | **PASS** |
| Blood Group | `bloodGroup` | `bloodGroup` | String | YES | 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' | **PASS** |
| Height | `heightCm` / `height` | `heightCm` | Number | YES | Numeric > 0 (cm) | **PASS** |
| Weight | `weightKg` / `weight` | `weightKg` | Number | YES | Numeric > 0 (kg) | **PASS** |
| Known Allergies | `allergies` | `allergies` | [String] | NO | Optional array / comma-separated list | **PASS** |
| Existing Conditions | `chronicConditions` / `existingConditions` | `chronicConditions` | [String] | NO | Optional array / comma-separated list | **PASS** |
| Current Medications | `emergencyMedicalInfo` / `currentMedications` | `emergencyMedicalInfo` | String | NO | Optional text description | **PASS** |
| Emergency Contact Name | `emergencyContactName` | `emergencyContactName` | String | NO | Optional string | **PASS** |
| Emergency Country Code | `emergencyCountryCode` | `emergencyCountryCode` | String | NO | e.g. '+91', '+1' | **PASS** |
| Emergency Phone | `emergencyPhone` / `phoneNumber` | `emergencyPhone` | String | NO | 7–15 numeric digits | **PASS** |
| Emergency Relationship | `emergencyRelationship` | `emergencyRelationship` | String | NO | e.g. 'Dad', 'Mother', 'Spouse' | **PASS** |
| Profile Picture URL | `profilePictureUrl` / `profileImagePath` | `profilePictureUrl` | String | NO | Storage path or URL | **PASS** |
| Profile Completed Status | `profileCompleted` / `isProfileComplete` | `profileCompleted` | Boolean | YES | Automatically computed on save | **PASS** |
