# MEDGUARD — Production Deployment & Local Setup Guide

## 1. Node.js Backend Setup

### Prerequisites
- Node.js 20+ (Tested on v24.16.0)
- npm 10+
- Access to MongoDB Atlas Cluster

### Installation
```bash
cd /Users/hemachandra/Mobile_App_Dev/med_ai/backend
npm install
```

### Environment Configuration (`backend/.env`)
Ensure `backend/.env` contains the following variables:
```env
MONGODB_USERNAME=hemachandra1196_db_user
MONGODB_PASSWORD=Hemachandra@1196
MONGODB_HOST=medguardcluster.maylg97.mongodb.net
DB_NAME=medguard
PORT=5001
JWT_SECRET=medguard_production_jwt_secret_key_2026_secure
JWT_EXPIRES_IN=7d
```

### Verification & Diagnostic Tests
Run diagnostic test suite to verify TLS, DNS SRV, and write/read access:
```bash
npm run test:db
```

### Starting the Backend Server
```bash
# Production mode
npm start

# Development mode
npm run dev
```

---

## 2. Flutter Frontend Setup

### Prerequisites
- Flutter SDK 3.12+ (Dart 3.12+)
- Android Studio / Xcode (for native builds)

### Analysis & Testing
```bash
cd /Users/hemachandra/Mobile_App_Dev/med_ai
flutter analyze
flutter test
```

### Target Execution Commands

#### 1. Flutter Web
```bash
flutter run -d chrome --web-port 3000
```

#### 2. Android Emulator
```bash
flutter run -d emulator-5554
```

#### 3. Physical Android Phone
Ensure phone and host computer are on the same Wi-Fi network or connected via USB debugging.
```bash
flutter run -d <device_id>
```
