# MEDGUARD — Feature API Endpoints Specification

## Base Server Configuration
- **Protocol:** HTTP / REST
- **Default Port:** `5001`
- **Base URI:** `http://localhost:5001/api`
- **Authentication:** Bearer JWT Header (`Authorization: Bearer <TOKEN>`)

---

## 1. Authentication & Profiles (`/auth` & `/users`)
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| POST | `/api/auth/register` | Register new user with email, password, fullName | No |
| POST | `/api/auth/login` | Authenticate and obtain JWT token | No |
| GET | `/api/users/me` | Fetch authenticated user's complete profile | Yes |
| PUT | `/api/users/me` | Update personal health profile (height, weight, age, etc.) | Yes |

---

## 2. Medicine Management (`/medicines`)
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| GET | `/api/medicines` | Retrieve user's active medication list | Yes |
| POST | `/api/medicines` | Add a new medicine schedule | Yes |
| PUT | `/api/medicines/:id` | Update medication details | Yes |
| DELETE | `/api/medicines/:id` | Delete medicine entry | Yes |
| POST | `/api/medicines/:id/take` | Record dose taken and deduct stock count | Yes |
| POST | `/api/medicines/:id/skip` | Record dose skipped without stock change | Yes |

---

## 3. Health Vault (`/health-records`)
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| GET | `/api/health-records` | Retrieve all health vault documents | Yes |
| POST | `/api/health-records` | Upload/create new health record | Yes |
| GET | `/api/health-records/:id` | Retrieve single document metadata | Yes |
| GET | `/api/health-records/:id/download`| Direct download link for record attachment | Yes |
| PUT | `/api/health-records/:id` | Update record title, type, notes | Yes |
| DELETE | `/api/health-records/:id` | Delete record from vault | Yes |

---

## 4. Clinical Appointments (`/appointments`)
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| GET | `/api/appointments` | Retrieve scheduled appointments | Yes |
| POST | `/api/appointments` | Book new clinical visit with reminders | Yes |
| PUT | `/api/appointments/:id` | Update appointment details or status | Yes |
| DELETE | `/api/appointments/:id` | Delete appointment record | Yes |

---

## 5. Wellness & Hydration (`/wellness`)
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| GET | `/api/wellness/water/today` | Fetch today's consumed fluid ml & daily target | Yes |
| POST | `/api/wellness/water/log` | Log an intake amount (+200ml, +250ml, etc.) | Yes |
| POST | `/api/wellness/water/undo` | Undo the last logged fluid entry | Yes |
| POST | `/api/wellness/water/reset` | Reset today's fluid counter to 0 ml | Yes |
| PUT | `/api/wellness/water/target` | Update daily hydration goal (or clinician limit)| Yes |

---

## 6. Emergency Contacts & Voice SOS (`/emergency`)
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| GET | `/api/emergency/contacts` | List verified emergency contacts | Yes |
| POST | `/api/emergency/contacts` | Add new emergency contact | Yes |
| PUT | `/api/emergency/contacts/:id` | Update contact info or primary flag | Yes |
| DELETE | `/api/emergency/contacts/:id`| Remove emergency contact | Yes |
| POST | `/api/emergency/sos/trigger` | Log emergency SOS event with real coordinates | Yes |
| GET | `/api/emergency/sos/history` | Retrieve historical SOS trigger events | Yes |
