# MEDGUARD MongoDB Atlas Schema Documentation

This document outlines the complete Mongoose 9 database schemas implemented for the MEDGUARD backend on MongoDB Atlas.

## Collections & Schemas Overview

### 1. `users` (User Model)
- `email`: String (required, unique, lowercase, trimmed)
- `password`: String (hashed using bcryptjs)
- `fullName`: String (required)
- `phoneNumber`: String
- `age`: Number
- `gender`: String ('Male', 'Female', 'Other', 'Prefer not to say')
- `bloodGroup`: String ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
- `heightCm`: Number
- `weightKg`: Number
- `allergies`: [String]
- `chronicConditions`: [String]
- `emergencyMedicalInfo`: String
- `profilePictureUrl`: String
- `firebaseUid`: String (sparse index for Firebase migration/linking)
- `role`: String ('user', 'admin')
- `isActive`: Boolean
- `lastLoginAt`: Date
- `createdAt`, `updatedAt`: Date (timestamps)

### 2. `usersessions` (UserSession Model)
- `userId`: ObjectId (ref: User, indexed)
- `token`: String (JWT)
- `deviceInfo`: String
- `ipAddress`: String
- `expiresAt`: Date
- `isActive`: Boolean
- `createdAt`, `updatedAt`: Date

### 3. `medicines` (Medicine Model)
- `userId`: ObjectId (ref: User, indexed)
- `name`: String (required)
- `dosage`: String (required)
- `times`: [String] (HH:mm format e.g. "08:00")
- `frequency`: String ('Daily', 'Weekly', etc.)
- `totalStock`: Number
- `remainingStock`: Number
- `instructions`: String
- `startDate`: Date
- `endDate`: Date
- `isActive`: Boolean
- `createdAt`, `updatedAt`: Date

### 4. `medicationlogs` (MedicationLog Model)
- `userId`: ObjectId (ref: User, indexed)
- `medicineId`: ObjectId (ref: Medicine, indexed)
- `medicineName`: String
- `dosage`: String
- `scheduledTime`: String
- `status`: String ('taken', 'skipped', 'missed')
- `takenAt`: Date
- `missedReason`: String
- `createdAt`, `updatedAt`: Date

### 5. `appointments` (Appointment Model)
- `userId`: ObjectId (ref: User, indexed)
- `doctorName`: String (required)
- `specialty`: String
- `hospitalName`: String (required)
- `appointmentDate`: Date (required)
- `appointmentTime`: String (required)
- `reason`: String
- `status`: String ('upcoming', 'completed', 'cancelled')
- `notes`: String
- `pdfPath`: String (path to generated summary PDF)
- `createdAt`, `updatedAt`: Date

### 6. `healthrecords` (HealthRecord Model)
- `userId`: ObjectId (ref: User, indexed)
- `title`: String (required)
- `category`: String ('lab', 'prescription', 'scan', 'other')
- `filePath`: String (relative file storage path)
- `fileName`: String
- `mimeType`: String
- `fileSizeBytes`: Number
- `tags`: [String]
- `notes`: String
- `createdAt`, `updatedAt`: Date

### 7. `emergencycontacts` (EmergencyContact Model)
- `userId`: ObjectId (ref: User, indexed)
- `name`: String (required)
- `relation`: String (required)
- `phone`: String (required)
- `isPrimary`: Boolean
- `createdAt`, `updatedAt`: Date

### 8. `emergencyevents` (EmergencyEvent Model)
- `userId`: ObjectId (ref: User, indexed)
- `triggerType`: String ('voice', 'manual', 'shake')
- `location`: { latitude: Number, longitude: Number, address: String }
- `contactsNotified`: [{ contactId: ObjectId, name: String, phone: String, status: String }]
- `status`: String ('active', 'resolved', 'cancelled')
- `triggeredAt`: Date
- `resolvedAt`: Date
- `createdAt`, `updatedAt`: Date

### 9. `waterintakes` (WaterIntake Model)
- `userId`: ObjectId (ref: User, indexed)
- `date`: String (YYYY-MM-DD, compound unique index with userId)
- `targetMl`: Number
- `consumedMl`: Number
- `logs`: [{ time: String, amountMl: Number, timestamp: Date }]
- `createdAt`, `updatedAt`: Date

### 10. `bmihistories` (BmiHistory Model)
- `userId`: ObjectId (ref: User, indexed)
- `weightKg`: Number
- `heightCm`: Number
- `bmi`: Number
- `category`: String
- `calculatedAt`: Date
- `createdAt`, `updatedAt`: Date

### 11. `notificationpreferences` (NotificationPreference Model)
- `userId`: ObjectId (ref: User, unique index)
- `medicineReminders`: Boolean
- `appointmentReminders`: Boolean
- `waterReminders`: Boolean
- `sosAlerts`: Boolean
- `pushToken`: String
- `createdAt`, `updatedAt`: Date

### 12. `auditevents` (AuditEvent Model)
- `userId`: ObjectId (ref: User, indexed)
- `action`: String
- `ipAddress`: String
- `userAgent`: String
- `details`: Object
- `createdAt`, `updatedAt`: Date
