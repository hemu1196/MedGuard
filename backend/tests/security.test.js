const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdtemp, rm } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { once } = require('node:events');
process.env.JWT_SECRET = 'test-only-secret-' + 'x'.repeat(48);
const mongoose = require('mongoose');
const { app } = require('../index');
const User = require('../src/models/User');
const Session = require('../src/models/UserSession');
const PasswordReset = require('../src/models/PasswordReset');
const recovery = require('../src/services/passwordRecoveryService');
const firebase = require('../src/services/firebaseIdentityService');
const { generateToken, verifyToken } = require('../src/utils/jwt');

async function freePort() {
  const server = net.createServer().listen(0, '127.0.0.1');
  await once(server, 'listening');
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

test('MEDGUARD API security and feature regression (isolated local MongoDB)', { timeout: 90000 }, async (t) => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'medguard-test-'));
  const port = await freePort();
  const mongo = spawn(process.env.MONGOD_BIN || 'mongod', ['--dbpath', dir, '--port', String(port), '--bind_ip', '127.0.0.1', '--quiet'], { stdio: 'ignore' });
  let startupError;
  mongo.on('error', (error) => { startupError = error; });
  let server;
  t.after(async () => {
    if (server) await new Promise((resolve) => server.close(resolve));
    if (mongoose.connection.readyState === 1) {
      const appointments = await mongoose.connection.collection('appointments').find({}).toArray();
      for (const appointment of appointments) if (appointment.pdfPath) await rm(appointment.pdfPath, { force: true });
    }
    await mongoose.disconnect();
    if (mongo.exitCode === null && !startupError) {
      const ended = once(mongo, 'exit');
      mongo.kill('SIGTERM');
      await ended;
    }
    await rm(dir, { recursive: true, force: true });
  });
  let connected = false;
  for (let i = 0; i < 30; i++) {
    if (startupError) throw new Error('Install mongod or set MONGOD_BIN to run the isolated backend suite.');
    try {
      await mongoose.connect(`mongodb://127.0.0.1:${port}/medguard_test`, { serverSelectionTimeoutMS: 300 });
      connected = true; break;
    } catch (_) { await new Promise((r) => setTimeout(r, 100)); }
  }
  assert.ok(connected, 'Local test MongoDB must start');
  await Promise.all([User.init(), Session.init(), PasswordReset.init()]);
  server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  async function api(route, body, token, method = body ? 'POST' : 'GET') {
    const response = await fetch(base + '/api' + route, {
      method,
      headers: { ...(body instanceof FormData ? {} : { 'Content-Type': 'application/json' }), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body instanceof FormData ? body : body ? JSON.stringify(body) : undefined,
    });
    const type = response.headers.get('content-type') || '';
    return { status: response.status, data: type.includes('json') ? await response.json() : Buffer.from(await response.arrayBuffer()), headers: response.headers };
  }
  let a, b;
  await t.test('registration hashes passwords and prevents duplicate accounts', async () => {
    a = (await api('/auth/register', { email: 'alice@example.test', password: 'Secret123!', fullName: 'Alice' })).data;
    b = (await api('/auth/register', { email: 'bob@example.test', password: 'Secret123!', fullName: 'Bob' })).data;
    assert.ok(a.token && b.token);
    assert.equal(a.user.password, undefined);
    const user = await User.findById(a.user._id);
    assert.notEqual(user.password, 'Secret123!');
    assert.ok(await user.comparePassword('Secret123!'));
    assert.equal((await api('/auth/register', { email: 'alice@example.test', password: 'Secret123!', fullName: 'Alice' })).status, 400);
  });
  await t.test('login accepts correct credentials and rejects incorrect credentials', async () => {
    assert.equal((await api('/auth/login', { email: 'alice@example.test', password: 'wrong' })).status, 401);
    assert.equal((await api('/auth/login', { email: 'alice@example.test', password: 'Secret123!' })).status, 200);
    assert.equal((await api('/users/me', null, a.token)).status, 200);
  });
  await t.test('forged and unregistered JWT sessions are rejected', async () => {
    assert.equal((await api('/users/me', null, a.token + 'x')).status, 401);
    const unsignedSession = generateToken({ userId: a.user._id });
    assert.equal((await api('/users/me', null, unsignedSession)).status, 401);
  });
  await t.test('JWTs are unique and missing signing configuration fails closed', () => {
    assert.notEqual(generateToken({ userId: 'same' }), generateToken({ userId: 'same' }));
    const saved = process.env.JWT_SECRET;
    delete process.env.JWT_SECRET;
    assert.throws(() => generateToken({ userId: 'same' }), /JWT_SECRET/);
    process.env.JWT_SECRET = saved;
    assert.equal(verifyToken(a.token).userId, a.user._id);
  });
  await t.test('password reset cannot be performed with just an email', async () => {
    assert.equal((await api('/auth/reset-password', { email: 'alice@example.test', newPassword: 'Hijack123!' })).status, 400);
    assert.ok(await (await User.findById(a.user._id)).comparePassword('Secret123!'));
  });
  await t.test('Firebase identity cannot be supplied as an unverified email or UID', async () => {
    assert.equal((await api('/auth/firebase-migrate', { email: 'alice@example.test', firebaseUid: 'attacker', password: 'Hijack123!' })).status, 401);
    assert.equal((await api('/auth/firebase-migrate', { idToken: 'invalid' })).status, 401);
  });
  await t.test('verified Firebase migration preserves passwords and issues a registered session', async (st) => {
    st.mock.method(firebase, 'verifyIdentity', async () => ({ uid: 'verified-alice', email: 'alice@example.test', email_verified: true }));
    const result = await api('/auth/firebase-migrate', { idToken: 'verified-by-service', password: 'Untrusted123!' });
    assert.equal(result.status, 200);
    assert.equal((await api('/users/me', null, result.data.token)).status, 200);
    assert.ok(await (await User.findById(a.user._id)).comparePassword('Secret123!'));
  });
  await t.test('CORS permits localhost and rejects arbitrary and lookalike origins', async () => {
    for (const [origin, allowed] of [['http://localhost:8080', true], ['http://localhost.evil.test', false], ['https://evil.test', false]]) {
      const response = await fetch(base + '/api/health', { method: 'OPTIONS', headers: { Origin: origin, 'Access-Control-Request-Method': 'GET' } });
      assert.equal(response.headers.get('access-control-allow-origin'), allowed ? origin : null);
    }
  });
  let medicineId, appointmentId, recordId;
  await t.test('medicine CRUD preserves ownership and rejects malformed dose logs before stock mutation', async () => {
    const result = await api('/medicines', { name: 'Test medicine', dosage: '1 tablet', totalStock: 10 }, a.token);
    assert.equal(result.status, 201); medicineId = result.data.medicine._id;
    assert.equal((await api('/medicines/' + medicineId, { name: 'Stolen' }, b.token, 'PUT')).status, 404);
    assert.equal((await api('/medicines/log', { medicineId, scheduledTime: '08:00', status: 'invalid' }, a.token)).status, 400);
    const log = await api('/medicines/log', { medicineId, scheduledTime: '08:00', status: 'taken' }, a.token);
    assert.equal(log.status, 200); assert.equal(log.data.remainingStock, 9);
  });
  await t.test('appointments retain server-owned PDF paths and enforce ownership', async () => {
    const result = await api('/appointments', { doctorName: 'Test doctor', hospitalName: 'Test clinic', appointmentDate: '2026-12-15', appointmentTime: '10:30' }, a.token);
    assert.equal(result.status, 201); appointmentId = result.data.appointment._id;
    const updated = await api('/appointments/' + appointmentId, { pdfPath: '/etc/passwd', notes: 'Updated' }, a.token, 'PUT');
    assert.equal(updated.status, 200); assert.notEqual(updated.data.appointment.pdfPath, '/etc/passwd');
    assert.equal((await api('/appointments/' + appointmentId + '/pdf', null, b.token)).status, 404);
  });
  await t.test('GridFS vault upload and download work only for the owner', async () => {
    const form = new FormData(); form.set('title', 'Private record');
    form.set('file', new Blob(['%PDF-1.4\nPrivate test file'], { type: 'application/pdf' }), 'record.pdf');
    const result = await api('/health-records/upload', form, a.token);
    assert.equal(result.status, 201); recordId = result.data.record._id;
    const download = await api('/health-records/' + recordId + '/download', null, a.token);
    assert.equal(download.status, 200); assert.ok(download.data.toString().startsWith('%PDF'));
    assert.equal((await api('/health-records/' + recordId + '/download', null, b.token)).status, 404);
    assert.equal((await fetch(base + '/uploads/pdfs/Appointment_' + appointmentId + '.pdf')).status, 404);
  });
  await t.test('water and BMI reject invalid values and persist valid records', async () => {
    assert.equal((await api('/wellness/water', { amountMl: -250 }, a.token)).status, 400);
    assert.equal((await api('/wellness/water', { amountMl: 250 }, a.token)).data.waterIntake.consumedMl, 250);
    assert.equal((await api('/wellness/bmi', { weightKg: -70, heightCm: 175 }, a.token)).status, 400);
    assert.equal((await api('/wellness/bmi', { weightKg: 70, heightCm: 175 }, a.token)).status, 201);
  });
  await t.test('SOS logs pending contact handoff without claiming SMS delivery', async () => {
    assert.equal((await api('/emergency/contacts', { name: 'Contact', relation: 'Family', phone: '+919999999999' }, a.token)).status, 201);
    const sos = await api('/emergency/sos/trigger', { latitude: 17.4, longitude: 78.4, triggerType: 'manual' }, a.token);
    assert.equal(sos.status, 200); assert.equal(sos.data.contacts[0].status, 'pending');
  });
  await t.test('logout invalidates the session immediately', async () => {
    assert.equal((await api('/auth/logout', {}, b.token)).status, 200);
    assert.equal((await api('/users/me', null, b.token)).status, 401);
  });
  await t.test('token refresh creates a usable distinct session', async () => {
    const refreshed = await api('/auth/refresh', {}, a.token);
    assert.equal(refreshed.status, 200); assert.notEqual(refreshed.data.token, a.token);
    assert.equal((await api('/users/me', null, refreshed.data.token)).status, 200);
  });
  await t.test('password change checks current password and revokes sessions', async () => {
    assert.equal((await api('/auth/change-password', { currentPassword: 'wrong', newPassword: 'Next123!' }, a.token)).status, 401);
    assert.equal((await api('/auth/change-password', { currentPassword: 'Secret123!', newPassword: 'Next123!' }, a.token)).status, 200);
    assert.equal((await api('/users/me', null, a.token)).status, 401);
    assert.equal((await api('/auth/login', { email: 'alice@example.test', password: 'Secret123!' })).status, 401);
    a.token = (await api('/auth/login', { email: 'alice@example.test', password: 'Next123!' })).data.token;
    assert.ok(a.token);
  });
  await t.test('email recovery stores only a hash, consumes code once, and revokes sessions', async () => {
    let message;
    recovery.getTransport = () => ({ sendMail: async (mail) => { message = mail; } });
    assert.equal((await api('/auth/request-password-reset', { email: 'alice@example.test' })).status, 200);
    assert.equal(message.to, 'alice@example.test');
    const code = message.text.match(/[a-f0-9]{48}/)[0];
    const stored = await PasswordReset.findOne({ userId: a.user._id });
    assert.notEqual(stored.tokenHash, code); assert.equal(stored.tokenHash, recovery.hashToken(code));
    const payload = { email: 'alice@example.test', newPassword: 'Recovered123!', recoveryCode: code };
    assert.equal((await api('/auth/reset-password', payload)).status, 200);
    assert.equal((await api('/auth/reset-password', payload)).status, 400);
    assert.equal((await api('/users/me', null, a.token)).status, 401);
    assert.equal((await api('/auth/login', { email: 'alice@example.test', password: 'Recovered123!' })).status, 200);
  });
  await t.test('expired recovery tokens are rejected even before TTL cleanup', async () => {
    const code = 'a'.repeat(48);
    await PasswordReset.create({ userId: a.user._id, tokenHash: recovery.hashToken(code), expiresAt: new Date(Date.now() - 1000) });
    assert.equal((await api('/auth/reset-password', { email: 'alice@example.test', newPassword: 'NoChange123!', recoveryCode: code })).status, 400);
  });
  await t.test('recovery requests are rate limited', async () => {
    let response;
    for (let i = 0; i < 11; i++) response = await api('/auth/reset-password', {});
    assert.equal(response.status, 429);
  });
});
