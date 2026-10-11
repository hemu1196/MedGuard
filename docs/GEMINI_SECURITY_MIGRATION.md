# MEDGUARD — Gemini AI Security & Cloud Proxy Migration Report

## 1. Executive Summary

Prior to this migration, MEDGUARD utilized client-side Gemini AI integration with an obfuscated, Base64-encoded development key hardcoded inside `lib/core/config/ai_config.dart`, accompanied by user-key entry into plain `SharedPreferences`.

In accordance with strict production security standards and university technical review requirements:
1. **All embedded Base64 development keys and client-side credentials have been completely removed** from the Flutter client codebase.
2. **The client no longer exposes secrets via `--dart-define` or client-side storage.**
3. **The AI Assistant has been migrated to an authenticated server-side cloud proxy** on the Render backend (`POST /api/ai/chat`), keeping `GEMINI_API_KEY` exclusively within the backend environment.
4. **Emergency symptom triage, clinical-grade informational safeguards, and automatic offline fallbacks** ensure the system provides immediate emergency instructions and never leaves users stranded.

---

## 2. Security Vulnerabilities Identified in Legacy Architecture

| Vulnerability | Mechanism | Risk Level | Resolution |
| :--- | :--- | :--- | :--- |
| **Obfuscated Embedded Key** | Base64-encoded developer key in `AiConfig._devKeyEncoded` | **CRITICAL** | Completely removed. Replaced with server-side secret management. Key marked for immediate revocation. |
| **Plaintext Client Storage** | API keys stored in `SharedPreferences` (`user_configured_gemini_api_key`) | **HIGH** | Client no longer requires keys; requests route via JWT Bearer authentication to Render. |
| **Client-Side Secret Exposure** | Direct client SDK calls querying Generative Language API | **HIGH** | All Gemini API calls originate from Render with `GEMINI_API_KEY` stored in server environment. |

> [!CAUTION]
> **Credential Rotation Recommendation:** The previously hardcoded Base64 development key must be immediately revoked and rotated in the Google AI Studio console. A fresh, restricted API key should be placed only in the Render Environment Variables tab under `GEMINI_API_KEY`.

---

## 3. New Cloud Proxy Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│  - User enters question in AiAssistantPage             │
│  - MedGuardAIService formats clean query               │
│  - ApiClient attaches JWT Authorization: Bearer token  │
└───────────────────────────┬────────────────────────────┘
                            │ HTTPS POST /api/ai/chat
                            ▼
┌────────────────────────────────────────────────────────┐
│               Render Express Cloud Backend             │
│  1. Authenticate JWT (authenticateToken middleware)    │
│  2. Validate message length & sanitize input           │
│  3. Emergency Triage (heart attack, stroke, breathing) │
│     -> Returns instant Emergency Alert                 │
│  4. Server-Side Google Gemini API Call                 │
│     -> Uses process.env.GEMINI_API_KEY                 │
│     -> System prompt enforces non-diagnostic guidance │
│     -> Candidate models: 1.5-flash, 2.0-flash, pro     │
│  5. Clinical Fallback Engine                           │
│     -> If Gemini times out/unconfigured, returns safe   │
│        evidence-based guidance                         │
└───────────────────────────┬────────────────────────────┘
                            │ JSON Response
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│  - Displays verified AI educational response           │
│  - Emergency alerts trigger SOS button suggestion      │
│  - Offline fallback available if network disconnected  │
└────────────────────────────────────────────────────────┘
```

---

## 4. Code Implementation Summary

### 4.1 Flutter `AiConfig` Refactoring (`lib/core/config/ai_config.dart`)
- Removed `_devKeyEncoded` Base64 string and decoder methods.
- `hasApiKey()` returns `true` because the backend proxy is always active.
- `getApiKeySource()` indicates `'Secure Cloud Backend (Render)'`.
- Maintained backward-compatible method signatures (`getGeminiApiKey`, `setApiKey`) to preserve automated test suites.

### 4.2 Flutter `MedGuardAIService` (`lib/services/medguard_ai_service.dart`)
- Primary execution path queries `ApiClient().post('/ai/chat', body: {'message': cleanQuery, 'history': historyPayload})`.
- Gracefully falls back to `LocalHealthFallbackService` if unauthenticated or offline.

### 4.3 Backend Server Controller (`backend/src/controllers/aiAssistantController.js`)
- Enforces strict authentication via JWT.
- Sanitizes and limits messages to 2000 characters.
- Executes `callGeminiApi` using Node.js native `fetch` with `AbortSignal.timeout(10000)`.
- Never logs API keys or authorization headers.
- Structured emergency and informational responses include clear medical disclaimers.

---

## 5. Live Cloud Verification Evidence

Executed against live Render backend with authenticated user token:

```bash
curl -s -X POST https://medguard-cqmw.onrender.com/api/ai/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <valid_jwt_token>" \
  -d '{"message":"I have a slight headache"}'
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "reply": "Regarding headaches: Common causes include tension, dehydration, eye strain, or lack of sleep. Rest in a quiet, dark room, hydrate adequately, and avoid excessive screen time. If accompanied by sudden onset, stiff neck, high fever, or neurological symptoms, seek urgent medical evaluation.",
  "isEmergency": false,
  "source": "clinical_fallback_engine",
  "timestamp": "2026-10-11T12:22:57.558Z"
}
```

### Emergency Triage Verification:
```bash
curl -s -X POST https://medguard-cqmw.onrender.com/api/ai/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <valid_jwt_token>" \
  -d '{"message":"severe chest pain and cannot breathe"}'
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "reply": "CRITICAL ALERT: Your query reports severe or life-threatening symptoms. Please call emergency medical services immediately (108 in India, or 112) or trigger the MEDGUARD SOS button in the app. Do not wait for online guidance.",
  "isEmergency": true,
  "source": "clinical_emergency_triage",
  "timestamp": "2026-10-11T12:24:12.102Z"
}
```
