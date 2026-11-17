# MEDGUARD — authentication and launch verification update

18 November 2026 (India). Existing project retained at `/Users/hemachandra/Mobile_App_Dev/MedGuard_App`; branch `codex/launch-features`. This report describes code and evidence; it is not a public-launch sign-off.

## Authentication changes

The rejected-token persistence defect was reproduced in automated tests and corrected. Previously, HTTP 401 cleared only the in-memory token, allowing the next request to reload the rejected JWT from secure storage. Startup also accepted a local token/user pair without checking the backend, and profile reads could hide an authentication rejection behind cached data. Those code paths now fail securely.

- Session storage operations are serialized. Rejected/expired/malformed credentials are invalidated in memory and persistent storage.
- Responses carry their originating credential/generation. A late response cannot clear a newer login or return another session's downloaded data.
- Restored sessions use `/auth/verify`; local JWT parsing does not substitute for server signature/session verification. Silent Firebase revival after intentional sign-out was removed; explicit credential-based legacy login remains supported.
- Profile requests include an expected account ID. A stale form cannot submit using a different signed-in account.
- Onboarding saves a protected, account-bound draft before submission. Rejected credentials preserve that draft for same-account reauthentication; account switching and intentional logout clear it.
- Profile save remains an authenticated owner update. Dashboard navigation waits for server acknowledgement. The client no longer creates a duplicate emergency contact after the backend synchronizes the primary contact.
- The onboarding layout now supports a 360-pixel viewport: vertical steps, wrapping date/BMI/controls and expanded selectors. Desktop retains horizontal steps.
- New server sessions store SHA-256 token hashes. Existing clear-token session rows remain compatible and migrate when used successfully; no production migration was run here.

Principal files: `lib/core/api/api_client.dart`, `lib/repositories/auth_repository.dart`, `lib/repositories/profile_repository.dart`, `lib/services/profile_draft_store.dart`, `lib/screens/onboarding/health_profile_page.dart`, `backend/src/controllers/authController.js`, `backend/src/middleware/authMiddleware.js`, `backend/src/models/UserSession.js` and `test/auth_recovery_test.dart`.

The exact failure on the user's installed phone has NOT been reproduced by the agent. The automated results establish regression coverage of identified defects; the phone's complete install/register/onboarding/restart/logout flow still must pass. The user chose to connect the phone later.

## Additional security work

Production API responses use private/no-store caching and redact internal server errors; CORS requires configured web origins. Upload capacity/rate limits, legacy real-path/symlink checks, mandatory clean production downloads, scanner freshness checks and bounded request sizes were added. JSON bodies are limited to 1 MiB; supported multipart medical files retain their 30 MiB limit. AI conversations are size-bounded.

AI chat now asks permission before transmitting the question/recent conversation to MEDGUARD/Google Gemini; cancellation sends nothing. Clearing chat resets this consent. The backend enforces the consent flag. Optional user-supplied custom test keys migrate out of ordinary preferences into protected storage and clear on logout. No development Gemini key is bundled in current source.

The Git-history scan found a historical encoded Gemini credential in an older commit. Treat it as exposed and rotate the historical key in Google/AI Studio; do not merely remove it from current source. No key value is reproduced here. History was not rewritten or force-pushed. Firebase client-key findings require verification of appropriate API restrictions; they are not substitutes for Firebase rules/App Check. Public client keys must not authorize Gemini or unrelated APIs. Current-tree dummy JWT/key findings in tests are synthetic fixtures.

References: [Firebase API-key guidance](https://firebase.google.com/docs/projects/api-keys), [Android app signing](https://developer.android.com/studio/publish/app-signing).

## Verification and builds

Final exact counts, artifact hashes, commit and remote-push status are recorded in `MEDGUARD-delivery-receipt.md` after the final checks complete. The new authentication tests include:

- rejected credentials removed from persistent storage;
- malformed/missing-expiry JWT refusal;
- late 401 after a newer login;
- no cached-profile bypass after rejection;
- signup/profile save/restart verification/logout/relogin with a mocked HTTP server;
- the same persistence/logout flow using the real backend and isolated local MongoDB;
- repeated profile updates leave one account and one primary contact;
- server token hashes and legacy-session migration;
- draft preservation versus logout/account-switch cleanup;
- no stale-account profile transmission;
- dashboard waits for acknowledgement and rejected submissions retain the draft;
- onboarding at desktop and narrow mobile width;
- no AI transmission without consent and no plaintext custom-key preference.

These are automated/local tests. They do not establish live Gemini behavior, camera scanning, actual notifications/reboot, OEM storage behavior or production deletion.

`flutter doctor -v` reported pending Android licenses and incomplete iOS/macOS tooling. iOS/macOS release is outside this Android/Web delivery. Review/accept required Android licenses yourself with `flutter doctor --android-licenses`; no terms were accepted automatically.

## Backend, storage and backup evidence

Latest read-only live check: the root initially reported disconnected during startup; `/api/health/ready` subsequently returned HTTP 200/connected. `/api/auth/verify` without credentials returned 401. `/api/launch/grants` returned 404: the launch APIs remain undeployed. The current local backend was tested separately against isolated MongoDB, not deployed to that service.

Local Atlas ping/list-collection verification succeeded in an earlier check, but later attempts failed with TLS/server-selection errors. The full encrypted MongoDB/GridFS dump has NOT completed successfully. Do not treat backup tooling as a verified production recovery point.

An encrypted legacy-file archive was created outside Git and authenticated/tar-checked. Private archives and the recovery key are under `/Users/hemachandra/Documents/Codex/MedGuard-private`, in separate backup/key folders. No medical archive or recovery key is committed or included in downloadable source packages. Keep secure off-device copies separately. Online logical dumps are explicitly labeled best-effort, not point-in-time certified.

Private ClamAV Docker/configuration files and clean/EICAR/freshness verification tools are prepared. No daemon was provisioned or run here. Actual signature updates, encrypted/oversized/malicious file policy, private network connectivity, scanner outage and real upload tests remain operator gates. Production intentionally fails closed until configured.

## Seven-feature status

| Feature | Implemented/tested locally | Still needs real verification or external setup |
|---|---|---|
| Medical ID QR | Consent/selection, real QR publishing/rendering, owner controls, expiration/revocation/access checks | Another phone's camera, printed readability and deployed responder flow |
| Family Caregiver | Account-bound invites, scoped read-only access, acceptance/reissue/revoke, dependent acknowledgment | Two-device recovery; guardian/legal review. Editing and caregiver alerts are not claimed as complete. |
| Medicine | Recurrence/date/weekday/DST logic, original occurrences, snooze payloads, stock idempotency, corrections and retry outbox | Phone permissions, midnight/reboot/timezone/battery/force-stop, full adherence/missed-alert coverage. Rolling 30-day schedules refresh on open/resume. |
| Offline Emergency | Protected Android snapshot, encrypted portable cards, dialer/SMS handoff code and encryption/cache tests | Real offline persistence, GPS/permissions/handoffs, installed browser offline shell. Web reminders require a running page. |
| Vault Sharing | Owner/intended-recipient isolation, private original bytes, expiry/revoke, scanner protocol/freshness/size controls | Real scanner and signature updates, production clean/infected/unavailable cases, capacity and restore evidence |
| Hospital Search | Location/city/radius/category/distance/cache/throttling code and existing regression coverage | Provider capacity/terms; independent facility data accuracy. No live bed/ICU/ambulance capacity claim. |
| Privacy Center | Sessions/grants/export/deletion worker/audit/cache controls and local tests | Production deletion and backups/log/cache inventory, enforced retention, privacy/legal policy and restore drill |

## Existing modules and limits

Existing dashboard/BMI, appointments/PDF, health vault, SOS/voice/location, hospital/maps, ambulance dialer, water intake and profile/settings were preserved. The regression suite covers portions of these modules. Every visible control, provider integration and physical-device path has NOT been independently verified in this pass. Gemini clinical guidance is general information, not a diagnosis or certification. No real emergency calls/SMS dispatch were made.

## Operator actions before public launch

1. Deploy manually only after staging authentication, backup/restore and real scanner prerequisites pass. The user explicitly chose manual Render deployment.
2. Provision the private scanner, update signatures, set exact CORS origins/provider contact and verify backend readiness/revision and new routes. Use an always-on deletion worker/service and monitoring.
3. Resolve Atlas/tool connectivity without disabling TLS validation, then obtain/restore-check an appropriate consistent database/GridFS backup. Set retention only to an actual enforced policy.
4. Rotate the historical Gemini key; verify Firebase restrictions; configure real SMTP/Gemini credentials on the server and test those integrations without medical test data.
5. Create/configure the private Android upload key manually. The package ID still is `com.example.med_ai`; confirm intended permanent identity and matching Firebase/Play setup before release. No signed final AAB is claimed without that key.
6. Install the fresh test APK and perform the complete phone flow. Test the seven features and existing modules under the listed device/network conditions.
7. Complete privacy/terms/support/retention/provider and incident-response review. Do not call the app medically certified or emergency-service-integrated.
8. Review the development-branch diff/PR before merging into main. A verified code push is not production deployment or public-launch sign-off.

See `MEDGUARD-manual-release-steps.md` for the concrete signing, backup, Render and phone commands.
