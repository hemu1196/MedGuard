const http = require('http');

const PORT = 5001;
const TEST_ORIGIN = 'http://localhost:57624';

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

async function runTest() {
  console.log('====================================================');
  console.log('MEDGUARD — PROFILE API & CORS INTEGRATION TEST');
  console.log('====================================================\n');

  // STEP 1: Test CORS Preflight OPTIONS
  console.log('[STEP 1] Testing CORS Preflight on /api/auth/profile...');
  const preflightRes = await request({
    hostname: 'localhost',
    port: PORT,
    path: '/api/auth/profile',
    method: 'OPTIONS',
    headers: {
      Origin: TEST_ORIGIN,
      'Access-Control-Request-Method': 'PUT',
      'Access-Control-Request-Headers': 'authorization,content-type',
    },
  });

  console.log(`Preflight Status: ${preflightRes.statusCode} (Expected: 204)`);
  console.log(`Access-Control-Allow-Origin: ${preflightRes.headers['access-control-allow-origin']}`);
  console.log(`Access-Control-Allow-Methods: ${preflightRes.headers['access-control-allow-methods']}`);
  console.log(`Access-Control-Allow-Headers: ${preflightRes.headers['access-control-allow-headers']}`);

  if (preflightRes.statusCode !== 204) {
    throw new Error(`Preflight failed with status ${preflightRes.statusCode}`);
  }
  console.log(' -> STEP 1 PASSED: CORS preflight handled properly!\n');

  // STEP 2: Register or Login test user
  const testEmail = `test_profile_${Date.now()}@medguard.dev`;
  const testPassword = 'Password123!';
  console.log(`[STEP 2] Registering test user (${testEmail})...`);

  const regRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/register',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Origin: TEST_ORIGIN,
      },
    },
    {
      email: testEmail,
      password: testPassword,
      fullName: 'Dr. Test Physician',
    }
  );

  console.log(`Register Status: ${regRes.statusCode}`);
  if (regRes.statusCode !== 201 && regRes.statusCode !== 200) {
    throw new Error(`User registration failed: ${JSON.stringify(regRes.data)}`);
  }

  const token = regRes.data.token;
  console.log(`User Token received (length: ${token ? token.length : 0})`);
  console.log(' -> STEP 2 PASSED: Registered successfully!\n');

  // STEP 3: Save Health Profile via PUT /api/auth/profile
  console.log('[STEP 3] Updating Health Profile (PUT /api/auth/profile)...');
  const profilePayload = {
    fullName: 'Dr. Test Physician',
    dateOfBirth: '1995-05-15T00:00:00.000Z',
    gender: 'Male',
    bloodGroup: 'B+',
    heightCm: 178,
    weightKg: 74,
    allergies: ['Penicillin', 'Dust'],
    chronicConditions: ['None'],
    emergencyMedicalInfo: 'No regular medications',
    emergencyContactName: 'Jane Physician',
    emergencyCountryCode: '+91',
    emergencyPhone: '9876543210',
    emergencyRelationship: 'Spouse',
    profileCompleted: true,
  };

  const updateRes = await request(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/auth/profile',
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        Origin: TEST_ORIGIN,
      },
    },
    profilePayload
  );

  console.log(`Profile Update Status: ${updateRes.statusCode}`);
  if (updateRes.statusCode !== 200) {
    throw new Error(`Profile update failed: ${JSON.stringify(updateRes.data)}`);
  }

  const updatedUser = updateRes.data.user;
  console.log('Updated User Data from MongoDB Atlas:');
  console.log(` - Full Name: ${updatedUser.fullName}`);
  console.log(` - Date of Birth: ${updatedUser.dateOfBirth}`);
  console.log(` - Calculated Age: ${updatedUser.age} years`);
  console.log(` - Blood Group: ${updatedUser.bloodGroup}`);
  console.log(` - Height: ${updatedUser.heightCm} cm`);
  console.log(` - Weight: ${updatedUser.weightKg} kg`);
  console.log(` - Allergies: ${JSON.stringify(updatedUser.allergies)}`);
  console.log(` - Emergency Contact: ${updatedUser.emergencyContactName} (${updatedUser.emergencyPhone})`);
  console.log(` - Profile Completed: ${updatedUser.profileCompleted}`);

  if (!updatedUser.profileCompleted) {
    throw new Error('Expected profileCompleted to be true!');
  }
  console.log(' -> STEP 3 PASSED: Health profile saved and confirmed!\n');

  // STEP 4: Fetch Profile via GET /api/users/me
  console.log('[STEP 4] Fetching Profile (GET /api/users/me)...');
  const fetchRes = await request({
    hostname: 'localhost',
    port: PORT,
    path: '/api/users/me',
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      Origin: TEST_ORIGIN,
    },
  });

  console.log(`Fetch Status: ${fetchRes.statusCode}`);
  if (fetchRes.statusCode !== 200) {
    throw new Error(`Failed to fetch user profile: ${JSON.stringify(fetchRes.data)}`);
  }

  const fetchedUser = fetchRes.data.user;
  if (fetchedUser.age !== updatedUser.age || fetchedUser.bloodGroup !== 'B+') {
    throw new Error('Fetched user does not match saved data!');
  }
  console.log(`Verified Persisted Profile: ${fetchedUser.fullName}, Age: ${fetchedUser.age}, Blood: ${fetchedUser.bloodGroup}`);
  console.log(' -> STEP 4 PASSED: Profile persisted and reloaded successfully!\n');

  console.log('====================================================');
  console.log('ALL PROFILE PERSISTENCE & CORS TESTS PASSED!');
  console.log('====================================================');
}

runTest().catch((err) => {
  console.error('TEST ERROR:', err.message);
  process.exit(1);
});
