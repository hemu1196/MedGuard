# MEDGUARD — manual deployment and signing

Project: `/Users/hemachandra/Mobile_App_Dev/MedGuard_App`.
You chose to deploy Render and create the Android upload key yourself. These are instructions, not evidence that deployment/signing happened.

Do not deploy the current working tree as a public release yet: the identified authentication defects are fixed and locally regression-tested but still need the physical-phone pass; a consistent database backup/restore and actual scanner verification are also pending. Finish those gates before the production steps below.

## 1. Backend configuration

From the project:

```sh
cd /Users/hemachandra/Mobile_App_Dev/MedGuard_App/backend
npm ci
npm test
node scripts/verifyConfiguration.js
```

Use your working Render environment configuration for `MONGODB_USERNAME`, `MONGODB_PASSWORD`, `MONGODB_HOST`, `DB_NAME`, `JWT_SECRET` and `JWT_EXPIRES_IN`. Host must be just the cluster hostname, without a scheme/path/port. Separate variables receive the raw password; the URI builder percent-encodes it. Keep secrets out of Git and chat.

Use a high-entropy `JWT_SECRET` of at least 32 characters, identical on every backend instance. If you replace an existing secret, existing JWTs become invalid and users must sign in again. Never restore the removed hardcoded fallback. Set `NODE_ENV=production`. Set `CORS_ORIGINS` to the exact HTTPS web origin(s), separated by commas. Production no longer allows arbitrary localhost/LAN origins automatically. Configure SMTP if advertising email recovery, and keep `GEMINI_API_KEY` server-side.

The last live check returned MongoDB connected and readiness HTTP 200. The launch-grants route returned 404, so new launch APIs were not deployed. Local Atlas ping/list-collections verification succeeded once after earlier TLS failures. Later backup connections again failed with `ERR_SSL_TLSV1_ALERT_INTERNAL_ERROR`; investigate the actual Atlas network access list, local network/TLS path and tool connectivity. Do not disable TLS validation or open Atlas to every IP as a workaround.

## 2. Private medical-file scanner

Prepared files: `deploy/clamav/Dockerfile` and `deploy/clamav/clamd.conf`.

In Render, create a **Private Service**, using the same workspace/region/private network as the backend. Use this existing repository and the `deploy/clamav` Docker build context/root directory with its Dockerfile. Do not create a public scanner web service or expose port 3310 to the internet. Select adequate memory; ClamAV's documentation recommends at least 3 GiB, preferably 4 GiB. Review service costs yourself before creating it.

The Dockerfile uses the official `clamav/clamav:1.4` feature image. Review the supported release and pin the tested image digest before production. The supplied configuration rejects encrypted documents, macro-bearing OLE files and scans that exceed limits. It permits streams up to 32 MiB for the application's 30 MiB limit. Keep FreshClam enabled and confirm signature updates/reloads actually happen. The container/configuration has not been executed here because Docker/ClamAV is not installed locally.

Set backend environment variables:

```text
CLAMAV_HOST=<the scanner's private/internal hostname>
CLAMAV_PORT=3310
VAULT_SCAN_REQUIRED=true
CLAMAV_MAX_SIGNATURE_AGE_HOURS=72
```

From the backend environment that can reach that private hostname, run:

```sh
node scripts/verifyScanner.js
```

This checks signature freshness, a harmless clean stream, and the standard EICAR antivirus test fixture. It must pass against the actual daemon. Also test clean/blocked/unavailable-scanner uploads through the app in staging. Production fails closed when a scanner is missing, unavailable, stale or returns no clean verdict. Existing originals must be re-scanned before opening/sharing in production. Signature checks and mock protocol tests are not an antivirus deployment.

References: [ClamAV Docker](https://docs.clamav.net/manual/Installing/Docker.html), [ClamD network warning](https://docs.clamav.net/manual/Usage/Scanning.html), [Render private services](https://render.com/docs/private-services).

## 3. Backups and restoration

Private backup folders were created outside Git:

- Archives: `/Users/hemachandra/Documents/Codex/MedGuard-private/backups`
- Recovery key: `/Users/hemachandra/Documents/Codex/MedGuard-private/keys/recovery.backup-key`

The key is not your Android signing key. Do not paste it into chat or commit it. Keep a secure off-device copy of the key separately from the archives. Two folders on this laptop are not an independent disaster-recovery system.

An encrypted legacy-uploads archive was created and authenticated; tar integrity passed. A full MongoDB/GridFS dump was attempted but did not complete successfully. There is no verified full database backup yet.

After resolving Atlas/tool connectivity:

```sh
cd /Users/hemachandra/Mobile_App_Dev/MedGuard_App/backend
node scripts/backup.js create \
  --key-file /Users/hemachandra/Documents/Codex/MedGuard-private/keys/recovery.backup-key \
  --out /Users/hemachandra/Documents/Codex/MedGuard-private/backups
```

Take the actual `backupPrefix` from its successful output. Verify each actual archive, replacing the example path with that output:

```sh
node scripts/backup.js verify \
  --key-file /Users/hemachandra/Documents/Codex/MedGuard-private/keys/recovery.backup-key \
  --archive /absolute/path/to/the-created-mongo.mgbackup
node scripts/backup.js verify \
  --key-file /Users/hemachandra/Documents/Codex/MedGuard-private/keys/recovery.backup-key \
  --archive /absolute/path/to/the-created-uploads.mgbackup
```

The database verification restores only to a temporary local loopback MongoDB and checks collection counts and GridFS lengths/chunk sequences. It never restores into production Atlas. MongoDB Database Tools and local `mongod` are required. This database restore path is not yet verified because no full dump succeeded.

These tools encrypt archives with AES-256-GCM and use a temporary mode-600 credentials file instead of putting the URI on the command line. Online logical dumps are explicitly labeled best-effort: counts and a successful restore do not prove point-in-time consistency. Use an appropriate Atlas snapshot/backup method or coordinated writes-off backup for the release recovery point. Configure an off-device retention schedule, restoration drills, access controls and backup-deletion policy. Set `BACKUP_RETENTION_DAYS` only after that policy really exists.

Reference: [MongoDB backup consistency guidance](https://www.mongodb.com/docs/manual/tutorial/backup-and-restore-tools/).

## 4. Render deployment — after release gates pass

Use the existing service, not a replacement app/database:
`https://dashboard.render.com/web/srv-db5m25dckfvc73am4gu0`

1. Verify the actual tested commit has been pushed. The intended development branch is `codex/launch-features`; use the exact remote commit recorded in the delivery receipt.
2. Use a separate staging database first; run authentication/onboarding and all feature scenarios with synthetic accounts. Keep production data untouched.
3. On the existing service, check branch/commit, root directory `backend`, build command `npm ci`, start command `npm start`, and health-check path `/api/health/ready`.
4. Review all environment variables above, actual scanner health, durable backup/restore evidence, provider contact and CORS. Set `HOSPITAL_PROVIDER_CONTACT` to the actual contact required by the geographic provider. An always-on service/compatible worker is required for deletion jobs to run continuously.
5. Record the prior live commit and environment configuration for rollback. After verified staging tests, manually deploy the reviewed exact commit. Do not apply destructive database migrations or reset collections.
6. Check these read-only endpoints:

```sh
curl --fail --show-error https://medguard-cqmw.onrender.com/
curl --fail --show-error https://medguard-cqmw.onrender.com/api/health/ready
curl --include https://medguard-cqmw.onrender.com/api/launch/grants
```

The root should show the intended `revision` after this code is deployed. Readiness must be 200. The private grants route without a token should return **401**, not 404. This does not substitute for authenticated tests.

7. Test register/login/profile save/logout with a synthetic staging account, QR revocation, intended-recipient Vault downloads, scanning, dose idempotency and deletion. Never put a JWT in a URL or share raw credential-bearing logs.
8. If new deployment fails health checks or authentication, use the recorded previous deploy for rollback and recheck readiness. Keep compatible deletion processing available. Do not roll back by restoring deleted medical records or revoked access grants into live traffic.

References: [Render health checks](https://render.com/docs/health-checks), [Render rollbacks](https://render.com/docs/rollbacks).

## 5. Create an Android upload key manually

If this package already has a Play Console upload key, use that existing key or its supported reset process. Do not create a different key and assume it can update the published app. The project still uses application ID `com.example.med_ai`; confirm the permanent identity before first store submission. Changing it requires coordinated Firebase configuration.

For a new, unpublished app, run these yourself:

```sh
mkdir -p /Users/hemachandra/Documents/Codex/MedGuard-private/signing
chmod 700 /Users/hemachandra/Documents/Codex/MedGuard-private/signing
keytool -genkeypair -v \
  -keystore /Users/hemachandra/Documents/Codex/MedGuard-private/signing/medguard-upload.jks \
  -storetype JKS -alias medguard-upload \
  -keyalg RSA -keysize 3072 -validity 10000
```

Enter passwords at the terminal prompts, not as command-line arguments. Keep a secure independent backup of the keystore and passwords. Then:

```sh
cd /Users/hemachandra/Mobile_App_Dev/MedGuard_App
cp android/key.properties.example android/key.properties
chmod 600 android/key.properties
nano android/key.properties
```

Fill these locally:

```properties
storePassword=<your keystore password>
keyPassword=<your key password>
keyAlias=medguard-upload
storeFile=/Users/hemachandra/Documents/Codex/MedGuard-private/signing/medguard-upload.jks
```

Replace placeholders; do not include angle brackets. Keep the file private. It and the keystore are excluded from Git.

After the authentication fix, backend deployment and final regression checks:

```sh
cd /Users/hemachandra/Mobile_App_Dev/MedGuard_App
flutter doctor -v
flutter clean
flutter pub get
flutter analyze
flutter test
MEDGUARD_REQUIRE_RELEASE_SIGNING=true flutter build apk --release \
  --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
MEDGUARD_REQUIRE_RELEASE_SIGNING=true flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
flutter build web --release \
  --dart-define=API_BASE_URL=https://medguard-cqmw.onrender.com
```

The signing configuration compiles in the test APK. The mandatory-key guard is checked separately; no signed AAB is produced without your private key. Do not treat a debug-signed build as a final release.

Expected output files, which must actually be checked after a successful build:

```text
/Users/hemachandra/Mobile_App_Dev/MedGuard_App/build/app/outputs/flutter-apk/app-release.apk
/Users/hemachandra/Mobile_App_Dev/MedGuard_App/build/app/outputs/bundle/release/app-release.aab
/Users/hemachandra/Mobile_App_Dev/MedGuard_App/build/web/
```

Verify the certificate against your upload key:

```sh
keytool -list -v \
  -keystore /Users/hemachandra/Documents/Codex/MedGuard-private/signing/medguard-upload.jks \
  -alias medguard-upload
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

Compare certificate SHA-256 fingerprints. A signature alone does not establish Play Console acceptance; complete the internal-test upload and review that result. Use the Play App Signing certificate when configuring services that validate the distributed Play-installed app. Reference: [Android app signing](https://developer.android.com/studio/publish/app-signing).

## 6. Physical phone test

Enable Developer options → USB debugging, connect USB and accept the computer authorization prompt:

```sh
adb devices -l
adb install -r /Users/hemachandra/Mobile_App_Dev/MedGuard_App/build/app/outputs/flutter-apk/app-release.apk
```

An APK signed with a different key cannot update the existing installation. Do not automatically uninstall to work around that: uninstalling removes local app data. Export needed data and make that choice yourself, or test on a separate device.

Record PASS/FAIL/BLOCKED for:

1. Register → login → health form → saved profile → dashboard. Verify saved values in the account, not just successful navigation.
2. Close/reopen → valid session restored; returning user skips completed onboarding; logout → protected request denied; login again.
3. Simulate expired/revoked session without bypassing JWT verification. Confirm reauthentication and form recovery.
4. Scan QR with another phone; selected fields only; expiry/revoke effective.
5. Two-account caregiver and intended-recipient Vault access; another account rejected; revoke/reissue checked.
6. Taken/Skip/Snooze, midnight, timezone, reboot, permission denial and battery restrictions. Compare server history and stock; test offline action resync.
7. Airplane mode card access and encrypted-card import; denied location; safe dialer/SMS composer handoff. Do not place real emergency calls during tests.
8. Clean/infected/unavailable scanner cases in staging; original download bytes and revocation.
9. Hospital radius/categories/distance/real facility accuracy; no invented emergency capacity.
10. Privacy export, session revoke and synthetic staging deletion; verify database/GridFS cleanup and documented backup retention.

Phone delivery, browser background behavior, legal/privacy policy and hospital capacity remain external verification gates.
