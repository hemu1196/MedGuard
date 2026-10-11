const express = require('express');
const mongoose = require('mongoose');
const http = require('http');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { connectDB, disconnectDB } = require('../config/database');
const User = require('../src/models/User');
const authRoutes = require('../src/routes/authRoutes');

const PORT = 5005;

async function makeRequest(method, path, body, headers = {}, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const req = http.request(
          {
            hostname: '127.0.0.1',
            port: PORT,
            path: `/api/auth${path}`,
            method,
            headers: {
              'Content-Type': 'application/json',
              ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
              ...headers,
            },
          },
          (res) => {
            let data = '';
            res.on('data', (chunk) => (data += chunk));
            res.on('end', () => {
              let json;
              try {
                json = JSON.parse(data);
              } catch (_) {
                json = data;
              }
              resolve({ status: res.statusCode, data: json });
            });
          }
        );
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
      });

      if (res.status === 500 && attempt < retries) {
        await new Promise((r) => setTimeout(r, 1000 * attempt));
        continue;
      }
      return res;
    } catch (err) {
      if (attempt < retries) {
        await new Promise((r) => setTimeout(r, 1000 * attempt));
        continue;
      }
      throw err;
    }
  }
}

async function runTests() {
  console.log('================================================================');
  console.log('MEDGUARD — LOGIN & PASSWORD AUTHENTICATION VERIFICATION SUITE');
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;

  function assert(title, condition, extra = '') {
    total++;
    if (condition) {
      passed++;
      console.log(`[PASS ${total}] ${title}`);
    } else {
      console.error(`[FAIL ${total}] ${title} ${extra}`);
      throw new Error(`Assertion failed: ${title}`);
    }
  }

  // 1. Connect to MongoDB Atlas
  console.log('[SETUP] Connecting to MongoDB Atlas...');
  await connectDB(5, 1000);

  // 2. Start Express app locally on PORT 5005
  const app = express();
  app.use(express.json());
  app.use('/api/auth', authRoutes);

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(PORT, '127.0.0.1', resolve));
  console.log(`[SETUP] Test Express server listening on http://127.0.0.1:${PORT}\n`);

  try {
    const testEmail = `test_auth_${Date.now()}@medguard.dev`;
    const testPassword = 'InitialPassword123!';
    const testFullName = 'Auth Test User';

    // TEST 1: New Registration
    const regRes = await makeRequest('POST', '/register', {
      email: testEmail,
      password: testPassword,
      fullName: testFullName,
    });
    assert('Registration returns HTTP 201', regRes.status === 201);
    assert('Registration returns success=true', regRes.data.success === true);
    assert('Registration returns JWT token', typeof regRes.data.token === 'string' && regRes.data.token.length > 20);
    assert('Registration returns accessToken alias', regRes.data.accessToken === regRes.data.token);
    assert('Registration does NOT leak password or hash', !regRes.data.user.password);
    assert('Registration normalized email in database', regRes.data.user.email === testEmail.toLowerCase());

    // TEST 2: Duplicate registration rejection
    const dupRes = await makeRequest('POST', '/register', {
      email: testEmail.toUpperCase(),
      password: 'AnotherPassword456!',
      fullName: 'Duplicate Tester',
    });
    assert('Duplicate registration rejected with HTTP 400', dupRes.status === 400);
    assert('Duplicate registration returns clear error message', dupRes.data.message.includes('already exists'));

    // TEST 3: Login with correct credentials
    const loginRes = await makeRequest('POST', '/login', {
      email: testEmail,
      password: testPassword,
    });
    assert('Login with correct credentials returns HTTP 200', loginRes.status === 200);
    assert('Login returns success=true', loginRes.data.success === true);
    assert('Login returns valid JWT', typeof loginRes.data.token === 'string');
    assert('Login does NOT leak password hash', !loginRes.data.user.password);

    // TEST 4: Email normalization with casing and whitespace
    const spacedCasedEmail = `  ${testEmail.toUpperCase()}  `;
    const normLoginRes = await makeRequest('POST', '/login', {
      email: spacedCasedEmail,
      password: testPassword,
    });
    assert('Login with cased & spaced email succeeds (normalized)', normLoginRes.status === 200);

    // TEST 5: Login with wrong password
    const wrongPassRes = await makeRequest('POST', '/login', {
      email: testEmail,
      password: 'IncorrectPassword999!',
    });
    assert('Login with wrong password returns HTTP 401', wrongPassRes.status === 401);
    assert('Login returns generic error message', wrongPassRes.data.message === 'Invalid email or password.');

    // TEST 6: Login with nonexistent email
    const unknownEmailRes = await makeRequest('POST', '/login', {
      email: 'nonexistent_account_999999@medguard.dev',
      password: testPassword,
    });
    assert('Login with unknown email returns HTTP 401', unknownEmailRes.status === 401);
    assert('Unknown email returns identical generic message (no enumeration)', unknownEmailRes.data.message === 'Invalid email or password.');

    // TEST 7: Password Reset flow
    const newPassword = 'NewSecretPassword789!';
    const resetRes = await makeRequest('POST', '/reset-password', {
      email: testEmail,
      newPassword,
    });
    assert('Password reset returns HTTP 200', resetRes.status === 200);
    assert('Password reset returns success=true', resetRes.data.success === true);
    assert('Password reset returns new JWT', typeof resetRes.data.token === 'string');

    // TEST 8: Old password rejected after reset
    const oldPassLoginRes = await makeRequest('POST', '/login', {
      email: testEmail,
      password: testPassword,
    });
    assert('Old password rejected with HTTP 401 after reset', oldPassLoginRes.status === 401);

    // TEST 9: New password succeeds after reset
    const newPassLoginRes = await makeRequest('POST', '/login', {
      email: testEmail,
      password: newPassword,
    });
    assert('New password succeeds with HTTP 200 after reset', newPassLoginRes.status === 200);
    assert('User profile preserved after password reset', newPassLoginRes.data.user.fullName === testFullName);

    // TEST 10: Existing users preservation check
    const existingCount = await User.countDocuments();
    assert('MongoDB Atlas users collection preserved intact', existingCount >= 9);

    console.log('\n================================================================');
    console.log(`VERIFICATION COMPLETE: ${passed}/${total} TESTS PASSED!`);
    console.log('================================================================\n');
  } finally {
    server.close();
    await disconnectDB();
  }
}

runTests().catch((err) => {
  console.error('[TEST SUITE CRASHED]', err);
  process.exit(1);
});
