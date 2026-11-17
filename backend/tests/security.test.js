const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdtemp, rm } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { once } = require('node:events');
process.env.LAUNCH_RATE_LIMIT = '1000';
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
  await Promise.all([User.init(), Session.init(), PasswordReset.init(), require('../src/models/AccessGrant').init(), require('../src/models/MedicationLog').init(), require('../src/models/FamilyProfile').init(), require('../src/models/DeletionRequest').init()]);
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
  await t.test('signup onboarding restart logout and relogin retain one MongoDB account and contact',async()=>{
    const credentials={email:'onboarding@example.test',password:'Synthetic-password-123',fullName:'Onboarding fixture'};
    const registered=await api('/auth/register',credentials);assert.equal(registered.status,201);const {token,user}=registered.data;
    const stored=await Session.collection.findOne({userId:new mongoose.Types.ObjectId(user._id)});assert.equal(stored.token,undefined);assert.match(stored.tokenHash,/^[a-f0-9]{64}$/);
    const profile={fullName:'Saved fixture',dateOfBirth:'2000-01-01',gender:'Male',bloodGroup:'O+',heightCm:175,weightKg:70,profileCompleted:true,emergencyContactName:'Fixture',emergencyPhone:'9999999999',emergencyRelationship:'Family'};
    for(let i=0;i<2;i++)assert.equal((await api('/auth/profile',profile,token,'PUT')).status,200);
    const restored=await api('/auth/verify',null,token);assert.equal(restored.status,200);assert.equal(restored.data.user.profileCompleted,true);assert.equal(restored.data.user.heightCm,175);
    assert.equal(await User.countDocuments({email:credentials.email}),1);assert.equal(await require('../src/models/EmergencyContact').countDocuments({userId:user._id}),1);
    assert.equal((await api('/auth/logout',{},token)).status,200);assert.equal((await api('/auth/verify',null,token)).status,401);
    const again=await api('/auth/login',credentials);assert.equal(again.status,200);assert.equal(again.data.user.profileCompleted,true);
  });
  await t.test('valid legacy sessions migrate to hashes without changing their JWT',async()=>{
    const token=generateToken({userId:a.user._id});await Session.create({userId:a.user._id,token,expiresAt:new Date(Date.now()+600000)});
    assert.equal((await api('/auth/verify',null,token)).status,200);
    const stored=await Session.collection.findOne({tokenHash:require('node:crypto').createHash('sha256').update(token).digest('hex')});assert.ok(stored);assert.equal(stored.token,undefined);
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
  await t.test('production API responses are private and do not leak internal errors', async (st) => {
    const previous=process.env.NODE_ENV;process.env.NODE_ENV='production';
    try {
      const response=await fetch(base+'/api/health',{method:'OPTIONS',headers:{Origin:'http://localhost:8080','Access-Control-Request-Method':'GET'}});
      assert.equal(response.headers.get('access-control-allow-origin'),null);
      st.mock.method(mongoose.connection.db,'admin',()=>({ping:async()=>{throw Error('private health payload and credential');}}));
      const failed=await api('/health/ready');assert.equal(failed.status,503);
      assert.equal(failed.data.message,'Service temporarily unavailable. Please retry later.');
      assert.match(failed.headers.get('cache-control'),/no-store/);
      const unknown=await api('/unknown/private-token-value');assert.equal(unknown.status,404);
      assert.ok(!JSON.stringify(unknown.data).includes('private-token-value'));
    } finally {if(previous===undefined)delete process.env.NODE_ENV;else process.env.NODE_ENV=previous;}
  });
  await t.test('legacy file paths cannot escape the uploads directory or follow outside symlinks', async () => {
    const fs=require('node:fs/promises'),storage=require('../src/services/storageService');
    const inside=path.join(storage.UPLOADS_DIR,'security-fixture.txt'),outside=path.join(dir,'private.txt'),link=path.join(storage.UPLOADS_DIR,'security-link.txt');
    await fs.writeFile(inside,'synthetic');await fs.writeFile(outside,'synthetic private');await fs.symlink(outside,link);
    try{assert.equal(storage.safeLegacyPath(inside),inside);assert.throws(()=>storage.safeLegacyPath(outside));assert.throws(()=>storage.safeLegacyPath(link));}
    finally{await fs.rm(inside,{force:true});await fs.rm(link,{force:true});}
  });

  await t.test('AI chat requires explicit consent before provider processing',async()=>{assert.equal((await api('/ai/chat',{message:'Synthetic fixture question'},a.token)).status,400);});
  await t.test('oversized JSON is rejected before unauthenticated processing',async()=>{const r=await api('/auth/login',{payload:'x'.repeat(1024*1024+1)});assert.equal(r.status,413);});
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
  await t.test('medical ID links expose selected fields only and support revocation', async () => {
    const result = await api('/launch/grants', { consent: true, kind: 'medical-id', fields: ['fullName', 'bloodGroup'] }, a.token);
    assert.equal(result.status, 201);
    assert.equal(result.data.grant.tokenHash, undefined);
    const Grant = require('../src/models/AccessGrant');
    const stored = await Grant.findById(result.data.grant._id).select('+tokenHash');
    assert.notEqual(stored.tokenHash, result.data.token);
    const view = await api('/launch/public/' + result.data.token);
    assert.equal(view.status, 200); assert.match(view.data.toString(), /Alice/);
    assert.doesNotMatch(view.data.toString(), /alice@example.test/);
    assert.match(view.headers.get('cache-control'), /no-store/);
    assert.equal((await api('/launch/grants/' + result.data.grant._id, null, b.token, 'DELETE')).status, 404);
    assert.equal((await api('/launch/grants/' + result.data.grant._id, null, a.token, 'DELETE')).status, 200);
    assert.equal((await api('/launch/public/' + result.data.token)).status, 404);
    assert.equal((await api('/launch/grants', { consent: true, kind: 'medical-id', fields: ['password'] }, a.token)).status, 400);
  });
  await t.test('expired links fail closed without waiting for database cleanup', async () => {
    const grant = (await api('/launch/grants', { consent: true, kind: 'medical-id', fields: ['fullName'] }, a.token)).data;
    await require('../src/models/AccessGrant').updateOne({ _id: grant.grant._id }, { expiresAt: new Date(Date.now() - 1000) });
    assert.equal((await api('/launch/public/' + grant.token)).status, 404);
  });
  await t.test('caregiver acceptance binds email, scopes, expiry and revocation', async () => {
    const invitation = (await api('/launch/grants', { consent: true, kind: 'caregiver', recipientEmail: 'bob@example.test', permissions: ['medicines'] }, a.token)).data;
    assert.equal((await api('/launch/caregiver/accept', { token: invitation.token }, a.token)).status, 404);
    const accepted = await api('/launch/caregiver/accept', { token: invitation.token }, b.token);
    assert.equal(accepted.status, 200);
    assert.equal((await api('/launch/caregiver/accept', { token: invitation.token }, b.token)).status, 404);
    const path = '/launch/caregiver/' + invitation.grant._id;
    assert.equal((await api(path + '/medicines', null, b.token)).status, 200);
    assert.equal((await api(path + '/profile', null, b.token)).status, 404);
    assert.equal((await api(path + '/medicines', null, a.token)).status, 404);
    assert.equal((await api('/launch/public/' + invitation.token)).status, 404);
    await api('/launch/grants/' + invitation.grant._id, null, a.token, 'DELETE');
    assert.equal((await api(path + '/medicines', null, b.token)).status, 404);
  });
  await t.test('vault grants select only owner records and serve exact original bytes', async () => {
    const rejected = await api('/launch/grants', { consent: true, kind: 'vault', recordIds: [recordId] }, b.token);
    assert.equal(rejected.status, 404);
    const grant = (await api('/launch/grants', { consent: true, kind: 'vault', recordIds: [recordId] }, a.token)).data;
    const file = await api('/launch/public/' + grant.token + '/files/' + recordId);
    assert.equal(file.status, 200); assert.equal(file.data.toString(), '%PDF-1.4\nPrivate test file');
    assert.match(file.headers.get('content-disposition'), /attachment/);
    const wrong = new mongoose.Types.ObjectId();
    assert.equal((await api('/launch/public/' + grant.token + '/files/' + wrong)).status, 404);
    await api('/launch/grants/' + grant.grant._id, null, a.token, 'DELETE');
    assert.equal((await api('/launch/public/' + grant.token + '/files/' + recordId)).status, 404);
  });
  await t.test('family cloud records isolate accounts and reject ownership injection', async () => {
    const body = { name: 'Test dependent', relationship: 'Parent', dateOfBirth: '1970-01-01', userId: b.user._id };
    const result = await api('/launch/family/fam_test', body, a.token, 'PUT');
    assert.equal(result.status, 200); assert.equal(result.data.member.userId, a.user._id);
    assert.equal((await api('/launch/family', null, b.token)).data.members.length, 0);
    await api('/launch/family/fam_test', null, b.token, 'DELETE');
    assert.equal((await api('/launch/family', null, a.token)).data.members.length, 1);
    assert.equal((await api('/launch/family/bad', { ...body, name: { $ne: null } }, a.token, 'PUT')).status, 400);
  });
  await t.test('concurrent duplicate medicine actions decrement stock once', async () => {
    const payload = { medicineId, scheduledTime: '09:00', scheduledDate: '2026-11-17', status: 'taken' };
    const before = await require('../src/models/Medicine').findById(medicineId);
    const replies = await Promise.all(Array.from({ length: 6 }, () => api('/medicines/log', payload, a.token)));
    assert.ok(replies.every(reply => reply.status === 200));
    const after = await require('../src/models/Medicine').findById(medicineId);
    assert.equal(after.remainingStock, before.remainingStock - 1);
    assert.equal(await require('../src/models/MedicationLog').countDocuments({ medicineId, scheduledDate: '2026-11-17', scheduledTime: '09:00' }), 1);
    assert.equal((await api('/medicines/log', { ...payload, status: 'skipped' }, a.token)).status, 409);
    assert.equal((await api('/medicines/log', { ...payload, scheduledDate: '2026-02-30' }, a.token)).status, 400);
  });
  await t.test('privacy exports require a password and exclude secrets and other accounts', async () => {
    assert.equal((await api('/launch/privacy/export', { password: 'wrong' }, a.token)).status, 403);
    const exported = await api('/launch/privacy/export', { password: 'Secret123!' }, a.token);
    assert.equal(exported.status, 200);
    assert.equal(exported.data.export.profile.password, undefined);
    assert.ok(exported.data.export.medicines.every(m => m.userId === a.user._id));
    const privacy = await api('/launch/privacy', null, a.token);
    assert.equal(privacy.status, 200); assert.ok(privacy.data.events.length);
    assert.ok(privacy.data.sessions.every(session => session.token === undefined));
  });
  await t.test('hospital classification uses source tags, never a medical-sounding name', () => {
    const { determineCategory, parseNominatimItem } = require('../src/controllers/hospitalController');
    assert.equal(determineCategory({ type: 'pharmacy' }, {}, 'Emergency Trauma Hospital'), 'pharmacy');
    assert.equal(determineCategory({}, {}, 'Emergency Hospital'), 'otherHealthcareFacility');
    const item = parseNominatimItem({ lat: '0', lon: '1', type: 'hospital', name: 'Test' }, 0, 0);
    assert.equal(item.emergencyServiceVerified, false);
    assert.ok(item.distanceMeters > 0);
  });
  await t.test('account deletion disables sessions and completes retryable private-data cleanup', async () => {
    const account = (await api('/auth/register', { email: 'delete@example.test', password: 'Delete123!', fullName: 'Delete Test' })).data;
    assert.equal((await api('/launch/privacy/delete-account', { password: 'wrong', confirmation: 'DELETE' }, account.token)).status, 400);
    const result = await api('/launch/privacy/delete-account', { password: 'Delete123!', confirmation: 'DELETE' }, account.token);
    assert.equal(result.status, 202);
    assert.equal((await api('/users/me', null, account.token)).status, 401);
    assert.equal((await api('/launch/deletion-status/' + result.data.receipt)).data.status, 'pending');
    assert.equal(await require('../src/services/deletionService').processOneDeletion(), true);
    assert.equal((await api('/launch/deletion-status/' + result.data.receipt)).data.status, 'complete');
    assert.equal(await User.findById(account.user._id), null);
    assert.equal(await require('../src/services/deletionService').processOneDeletion(), false);
  });
  await t.test('account-bound vault sharing requires intended account and cannot use public bearer access', async()=>{
    const invitation=(await api('/launch/grants',{consent:true,kind:'vault',recordIds:[recordId],recipientEmail:'bob@example.test'},a.token)).data;
    assert.equal((await api('/launch/public/'+invitation.token)).status,404);
    assert.equal((await api('/launch/caregiver/accept',{token:invitation.token},a.token)).status,404);
    assert.equal((await api('/launch/caregiver/accept',{token:invitation.token},b.token)).status,200);
    assert.equal((await api('/launch/vault/'+invitation.grant._id,null,a.token)).status,404);
    assert.equal((await api('/launch/vault/'+invitation.grant._id,null,b.token)).status,200);
    assert.equal((await api('/launch/vault/'+invitation.grant._id+'/files/'+recordId,null,b.token)).data.toString(),'%PDF-1.4\nPrivate test file');
    const replacement=await api('/launch/grants/'+invitation.grant._id+'/reissue',{},a.token);
    assert.equal(replacement.status,201);assert.equal((await api('/launch/vault/'+invitation.grant._id,null,b.token)).status,404);
    assert.equal((await api('/launch/caregiver/accept',{token:replacement.data.token},b.token)).status,200);
  });
  await t.test('minor dependent records require guardian acknowledgment and reject a known minor owner',async()=>{
    const payload={name:'Test dependent',relationship:'Child',dateOfBirth:'2020-01-01'};
    assert.equal((await api('/launch/family/minor_test',payload,a.token,'PUT')).status,400);
    assert.equal((await api('/launch/family/minor_test',{...payload,guardianAcknowledged:true},a.token,'PUT')).status,200);
    await User.updateOne({_id:a.user._id},{$set:{age:15}});
    assert.equal((await api('/launch/family/minor_test',{...payload,guardianAcknowledged:true},a.token,'PUT')).status,400);
    await User.updateOne({_id:a.user._id},{$set:{age:null}});
  });
  await t.test('audited dose corrections adjust stock once and reject stale corrections',async()=>{
    const history=(await api('/medicines/'+medicineId+'/history',null,a.token)).data;
    const receipt=history.receipts.find(r=>r.status==='taken');assert.ok(receipt);
    const correction={occurrenceId:receipt.occurrenceId,expectedStatus:'taken',status:'skipped',reason:'Accidental tap during test',operationId:'test-correction-operation-0001'};
    const result=await api('/medicines/'+medicineId+'/corrections',correction,a.token);assert.equal(result.status,200);assert.equal(result.data.remainingStock,history.remainingStock+1);
    assert.equal((await api('/medicines/'+medicineId+'/corrections',correction,a.token)).data.duplicate,true);
    assert.equal((await api('/medicines/'+medicineId+'/corrections',{...correction,operationId:'test-correction-operation-0002'},a.token)).status,409);
    const latest=(await api('/medicines/'+medicineId+'/history',null,a.token)).data;assert.equal(latest.corrections.length,1);assert.equal(latest.remainingStock,result.data.remainingStock);
    assert.equal((await api('/medicines/'+medicineId+'/history',null,b.token)).status,404);
  });
  await t.test('concurrent doses at depleted stock refund only actually debited units',async()=>{
    const med=(await api('/medicines',{name:'Stock fixture',dosage:'1 unit',totalStock:1},a.token)).data.medicine;
    const actions=await Promise.all(['10:00','11:00'].map(scheduledTime=>api('/medicines/log',{medicineId:med._id,scheduledTime,scheduledDate:'2026-11-17',status:'taken'},a.token)));
    assert.ok(actions.every(result=>result.status===200),JSON.stringify(actions.map(result=>({status:result.status,data:result.data}))));
    const history=(await api('/medicines/'+med._id+'/history',null,a.token)).data;
    assert.equal(history.remainingStock,0);assert.equal(history.receipts.reduce((sum,r)=>sum+r.stockDebited,0),1);
    for(const receipt of history.receipts) {
      const result=await api('/medicines/'+med._id+'/corrections',{occurrenceId:receipt.occurrenceId,expectedStatus:'taken',status:'skipped',reason:'Synthetic mistaken tap',operationId:'refund-test-'+receipt.occurrenceId},a.token);assert.equal(result.status,200);
    }
    assert.equal((await api('/medicines/'+med._id+'/history',null,a.token)).data.remainingStock,1);
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
