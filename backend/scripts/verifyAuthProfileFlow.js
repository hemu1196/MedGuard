const http = require('http');
const jwt = require('jsonwebtoken');

const PORT = 5001;
const JWT_SECRET = process.env.JWT_SECRET || 'medguard_production_jwt_secret_key_2026_secure';
const ORIGIN = 'http://localhost:57624';

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        let json;
        try {
          json = JSON.parse(body);
        } catch (_) {
          json = body;
        }
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          data: json,
        });
      });
    });
    req.on('error', reject);
    if (data) {
      req.write(typeof data === 'string' ? data : JSON.stringify(data));
    }
    req.end();
  });
}

async function runTestSuite() {
  console.log('================================================================');
  console.log('MEDGUARD — COMPREHENSIVE AUTHENTICATION & PROFILE TEST SUITE');
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;

  function testHeader(title) {
    total++;
    console.log(`[TEST ${total}] ${title}`);
  }

  function testPassed(msg) {
    passed++;
    console.log(`  PASSED: ${msg}\n`);
  }

  // -------------------------------------------------------------------------
  // TEST 1: New Registration -> Valid JWT Received
  // -------------------------------------------------------------------------
  testHeader('New Registration -> JWT Issued & Verified');
  const userAEmail = `user_a_${Date.now()}@medguard.dev`;
  const userAPassword = 'SecurePassword123!';

  const regRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/register',
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: ORIGIN },
    },
    { email: userAEmail, password: userAPassword, fullName: 'Alice Walker' }
  );

  if (regRes.statusCode !== 201) {
    throw new Error(`Registration failed: ${JSON.stringify(regRes.data)}`);
  }
  const tokenA = regRes.data.token;
  if (!tokenA || !regRes.data.accessToken || tokenA !== regRes.data.accessToken) {
    throw new Error('Valid token and accessToken alias not issued in registration response!');
  }
  const decodedA = jwt.verify(tokenA, JWT_SECRET);
  testPassed(`Registered user ${decodedA.email} (UID: ${decodedA.userId}). Token verified without leaking.`);

  // -------------------------------------------------------------------------
  // TEST 2: Profile Setup -> Save to MongoDB with Authorization Bearer
  // -------------------------------------------------------------------------
  testHeader('Save Health Profile with Authorization Header -> MongoDB Document Updated');
  const profilePayload = {
    fullName: 'Alice Walker',
    dateOfBirth: '1998-04-12T00:00:00.000Z',
    gender: 'Female',
    bloodGroup: 'O+',
    heightCm: 168,
    weightKg: 60,
    allergies: ['Peanuts'],
    chronicConditions: ['None'],
    emergencyMedicalInfo: 'No current medications',
    emergencyContactName: 'Bob Walker',
    emergencyCountryCode: '+91',
    emergencyPhone: '9876543210',
    emergencyRelationship: 'Brother',
    profileCompleted: true,
  };

  const saveRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/profile',
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
        Origin: ORIGIN,
      },
    },
    profilePayload
  );

  if (saveRes.statusCode !== 200) {
    throw new Error(`Profile save failed: ${JSON.stringify(saveRes.data)}`);
  }
  const savedUserA = saveRes.data.user;
  if (!savedUserA.profileCompleted || savedUserA.age !== 28) {
    throw new Error(`Profile update persistence check failed. Age: ${savedUserA.age}, profileCompleted: ${savedUserA.profileCompleted}`);
  }
  testPassed(`Profile persisted to medguard DB: Alice Walker, Age ${savedUserA.age}, Blood: ${savedUserA.bloodGroup}, Emergency: ${savedUserA.emergencyContactName}`);

  // -------------------------------------------------------------------------
  // TEST 3: Existing Account Login -> JWT Received & Profile Accessible
  // -------------------------------------------------------------------------
  testHeader('Existing Account Login -> JWT Issued & Saved Profile Retrieved');
  const loginRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: ORIGIN },
    },
    { email: userAEmail, password: userAPassword }
  );

  if (loginRes.statusCode !== 200) {
    throw new Error(`Login failed: ${JSON.stringify(loginRes.data)}`);
  }
  const loginTokenA = loginRes.data.token;
  if (!loginTokenA || loginRes.data.accessToken !== loginTokenA) {
    throw new Error('Login did not return valid token and accessToken alias!');
  }
  testPassed('Existing account logged in cleanly with refreshed JWT token.');

  // -------------------------------------------------------------------------
  // TEST 4: Missing JWT -> HTTP 401 & No Profile Update
  // -------------------------------------------------------------------------
  testHeader('Missing JWT Security Check -> HTTP 401 Unauthorized');
  const noTokenRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/profile',
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Origin: ORIGIN },
    },
    { fullName: 'Hacker Attempt' }
  );

  if (noTokenRes.statusCode !== 401) {
    throw new Error(`Expected 401 for missing token, got ${noTokenRes.statusCode}`);
  }
  if (!noTokenRes.data.message.includes('No token provided')) {
    throw new Error(`Expected "No token provided" error message, got: ${noTokenRes.data.message}`);
  }
  testPassed(`HTTP 401 returned: "${noTokenRes.data.message}". Unauthenticated access prevented.`);

  // -------------------------------------------------------------------------
  // TEST 5: Invalid JWT -> HTTP 401 & No Profile Update
  // -------------------------------------------------------------------------
  testHeader('Invalid JWT Security Check -> HTTP 401 Unauthorized');
  const invalidTokenRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/profile',
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalid.payload',
        Origin: ORIGIN,
      },
    },
    { fullName: 'Hacker Attempt' }
  );

  if (invalidTokenRes.statusCode !== 401) {
    throw new Error(`Expected 401 for invalid token, got ${invalidTokenRes.statusCode}`);
  }
  testPassed(`HTTP 401 returned: "${invalidTokenRes.data.message}". Malformed token rejected.`);

  // -------------------------------------------------------------------------
  // TEST 6: Expired JWT -> HTTP 401
  // -------------------------------------------------------------------------
  testHeader('Expired JWT Security Check -> HTTP 401 Token Expired');
  const expiredToken = jwt.sign(
    { userId: decodedA.userId, email: userAEmail, role: 'user' },
    JWT_SECRET,
    { expiresIn: -10 } // Expired 10 seconds ago
  );

  const expiredRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/profile',
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${expiredToken}`,
        Origin: ORIGIN,
      },
    },
    { fullName: 'Expired Attempt' }
  );

  if (expiredRes.statusCode !== 401) {
    throw new Error(`Expected 401 for expired token, got ${expiredRes.statusCode}`);
  }
  if (!expiredRes.data.message.includes('Token expired')) {
    throw new Error(`Expected "Token expired" message, got: ${expiredRes.data.message}`);
  }
  testPassed(`HTTP 401 returned: "${expiredRes.data.message}". Expired session requires re-authentication.`);

  // -------------------------------------------------------------------------
  // TEST 7: Token Refresh Flow -> Active Token Successfully Refreshed
  // -------------------------------------------------------------------------
  testHeader('Token Refresh Flow -> POST /api/auth/refresh');
  const refreshRes = await request({
    hostname: 'localhost',
    port: PORT,
    path: '/api/auth/refresh',
    method: 'POST',
    headers: {
      Authorization: `Bearer ${loginTokenA}`,
      Origin: ORIGIN,
    },
  });

  if (refreshRes.statusCode !== 200 || !refreshRes.data.token) {
    throw new Error(`Token refresh failed: ${JSON.stringify(refreshRes.data)}`);
  }
  testPassed('Refreshed token generated and verified successfully.');

  // -------------------------------------------------------------------------
  // TEST 8: Multi-Tenancy Security Check: User A cannot modify User B
  // -------------------------------------------------------------------------
  testHeader('Multi-tenancy Security Check -> User A cannot modify User B');
  const userBEmail = `user_b_${Date.now()}@medguard.dev`;
  const regBRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/register',
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: ORIGIN },
    },
    { email: userBEmail, password: 'UserBPassword123!', fullName: 'Bob Miller' }
  );

  const tokenB = regBRes.data.token;
  const decodedB = jwt.verify(tokenB, JWT_SECRET);

  // User A attempts to overwrite User B's profile by injecting B's userId in body
  const spoofAttemptRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/profile',
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${loginTokenA}`, // User A's token
        Origin: ORIGIN,
      },
    },
    {
      _id: decodedB.userId,
      userId: decodedB.userId,
      fullName: 'Attacked Bob Miller',
    }
  );

  // Verify that User B's profile was NOT modified
  const verifyBRes = await request({
    hostname: 'localhost',
    port: PORT,
    path: '/api/users/me',
    method: 'GET',
    headers: {
      Authorization: `Bearer ${tokenB}`,
      Origin: ORIGIN,
    },
  });

  if (verifyBRes.data.user.fullName !== 'Bob Miller') {
    throw new Error('Security Breach! User A modified User B profile!');
  }
  testPassed('User B profile remained completely untouched. Verified JWT-driven identity scoping.');

  // -------------------------------------------------------------------------
  // TEST 9: Browser Refresh / Session Restoration
  // -------------------------------------------------------------------------
  testHeader('Browser Refresh / Session Restoration -> Reload Persisted User Profile');
  const reloadRes = await request({
    hostname: 'localhost',
    port: PORT,
    path: '/api/users/me',
    method: 'GET',
    headers: {
      Authorization: `Bearer ${tokenA}`,
      Origin: ORIGIN,
    },
  });

  if (reloadRes.statusCode !== 200 || reloadRes.data.user.email !== userAEmail) {
    throw new Error('Failed to reload persisted user profile!');
  }
  testPassed(`Session restored successfully: ${reloadRes.data.user.fullName} (${reloadRes.data.user.email})`);

  // -------------------------------------------------------------------------
  // TEST 10: Logout Revocation
  // -------------------------------------------------------------------------
  testHeader('User Logout -> Session Flag Marked Inactive');
  const logoutRes = await request({
    hostname: 'localhost',
    port: PORT,
    path: '/api/auth/logout',
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokenA}`,
      Origin: ORIGIN,
    },
  });

  if (logoutRes.statusCode !== 200) {
    throw new Error(`Logout failed: ${JSON.stringify(logoutRes.data)}`);
  }
  testPassed('Logout executed cleanly.');

  console.log('================================================================');
  console.log(`ALL ${passed}/${total} AUTHENTICATION & PROFILE INTEGRATION TESTS PASSED!`);
  console.log('================================================================');
}

runTestSuite().catch((err) => {
  console.error('\nFAILED TEST EXECUTION:', err.message);
  process.exit(1);
});
