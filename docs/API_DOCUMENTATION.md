# MEDGUARD REST API Reference Specification

Base URL: `http://localhost:5001/api` (Web) / `http://10.0.2.2:5001/api` (Android Emulator)

## Security & Authentication
All protected endpoints require an HTTP `Authorization` header containing a valid Bearer JWT:
```text
Authorization: Bearer <jwt_token>
```

---

## 1. Authentication Endpoints (`/api/auth`)

### `POST /api/auth/register`
Creates a new user account in MongoDB Atlas.
- **Request Body**:
  ```json
  {
    "fullName": "John Doe",
    "email": "john@example.com",
    "password": "Password123!",
    "phoneNumber": "+919876543210"
  }
  ```
- **Response (201 Created)**:
  ```json
  {
    "success": true,
    "token": "<jwt>",
    "user": { "_id": "...", "fullName": "John Doe", "email": "john@example.com" }
  }
  ```

### `POST /api/auth/login`
Authenticates existing user credentials.
- **Request Body**:
  ```json
  {
    "email": "john@example.com",
    "password": "Password123!"
  }
  ```

### `GET /api/auth/me` *(Protected)*
Returns the current authenticated user's full profile.

### `PUT /api/auth/profile` *(Protected)*
Updates user profile fields (`fullName`, `age`, `gender`, `bloodGroup`, `heightCm`, `weightKg`, `allergies`, `chronicConditions`, `emergencyMedicalInfo`).

---

## 2. Medicine Endpoints (`/api/medicines`)

### `GET /api/medicines` *(Protected)*
Fetches all active medications for the user.

### `POST /api/medicines` *(Protected)*
Adds a new medicine item.
- **Request Body**:
  ```json
  {
    "name": "Paracetamol",
    "dosage": "500mg",
    "times": ["08:00", "20:00"],
    "frequency": "Daily",
    "totalStock": 30,
    "remainingStock": 30
  }
  ```

### `POST /api/medicines/log` *(Protected)*
Records dose intake action ('taken' or 'skipped') and automatically deducts 1 from `remainingStock` when status is 'taken'.

---

## 3. Health Vault Endpoints (`/api/health-records`)

### `GET /api/health-records` *(Protected)*
Fetches user uploaded health documents.

### `POST /api/health-records/upload` *(Protected, Multipart)*
Uploads document file (image/PDF) to local server storage disk.
- **Form Data**: `file` (binary), `title`, `category`, `notes`, `tags`.

### `GET /api/health-records/download/:recordId` *(Protected)*
Streams document file for inline viewing or local save.

---

## 4. Appointment Endpoints (`/api/appointments`)

### `GET /api/appointments` *(Protected)*
Fetches user appointments.

### `POST /api/appointments` *(Protected)*
Saves new appointment record and auto-generates printable PDF summary document.

### `GET /api/appointments/:appointmentId/pdf` *(Protected)*
Downloads PDF summary for appointment.

---

## 5. Emergency Endpoints (`/api/emergency`)

### `GET /api/emergency/contacts` *(Protected)*
Fetches emergency contacts.

### `POST /api/emergency/sos/trigger` *(Protected)*
Logs manual, voice, or shake SOS trigger event with GPS coordinates and generates Google Maps SMS link.

---

## 6. Wellness Endpoints (`/api/wellness`)

### `GET /api/wellness/water` *(Protected)*
Fetches today's water intake record.

### `POST /api/wellness/water` *(Protected)*
Logs consumed water volume in ml.

### `POST /api/wellness/bmi` *(Protected)*
Calculates and records BMI history entry.
