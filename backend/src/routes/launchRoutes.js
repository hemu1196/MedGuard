const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { authenticateToken } = require('../middleware/authMiddleware');
const Grant = require('../models/AccessGrant');
const Family = require('../models/FamilyProfile');
const User = require('../models/User');
const Medicine = require('../models/Medicine');
const Appointment = require('../models/Appointment');
const Record = require('../models/HealthRecord');
const Session = require('../models/UserSession');
const Audit = require('../models/AuditEvent');
const storage = require('../services/storageService');
const { medicalFields, hashToken, newToken, projectMedical, activeGrant, escapeHtml } = require('../services/accessPolicy');
const router = express.Router();
const id = value => typeof value === 'string' && /^[a-f\d]{24}$/i.test(value);
const wrap = fn => async (req, res, next) => { try { await fn(req, res); } catch (e) { next(e); } };
const limited = rateLimit({ windowMs: 15 * 60 * 1000, limit: 60, standardHeaders: 'draft-8', legacyHeaders: false });
function privateResponse(req, res, next) {
  res.set({ 'Cache-Control': 'no-store, private', 'Referrer-Policy': 'no-referrer', 'X-Robots-Tag': 'noindex, nofollow, noarchive', 'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'" });
  next();
}
router.use(privateResponse);
async function audit(userId, action, resourceId) {
  await Audit.create({ userId, action, details: { resourceType: 'access-grant', resourceId: String(resourceId) } });
}
function invalid(res, message) { return res.status(400).json({ success: false, message }); }

// Public bearer links deliberately expose only the owner's selected snapshot fields.
router.get('/public/:token', limited, wrap(async (req, res) => {
  if (!/^[A-Za-z0-9_-]{43}$/.test(req.params.token)) return res.sendStatus(404);
  const grant = await Grant.findOne({ tokenHash: hashToken(req.params.token) });
  if (!activeGrant(grant) || grant.kind === 'caregiver' || grant.recipientEmail) return res.sendStatus(404);
  const owner = await User.findOne({ _id: grant.ownerId, isActive: true });
  if (!owner) return res.sendStatus(404);
  if (grant.kind === 'medical-id') {
    const medical = projectMedical(owner, grant.fields);
    await audit(owner._id, 'medical-id.view', grant._id);
    const labels = { fullName: 'Name', bloodGroup: 'Blood group', allergies: 'Allergies', chronicConditions: 'Conditions', emergencyMedicalInfo: 'Medical notes / medicines', emergencyContactName: 'Emergency contact', emergencyCountryCode: 'Country code', emergencyPhone: 'Contact phone' };
    const rows = Object.entries(medical).map(([key, value]) => `<dt>${labels[key]}</dt><dd>${escapeHtml(Array.isArray(value) ? value.join(', ') || 'Not provided' : value || 'Not provided')}</dd>`).join('');
    res.type('html').send(`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MEDGUARD Medical ID</title><style>body{font:18px system-ui;max-width:680px;margin:32px auto;padding:20px;color:#172a35}dt{font-weight:700;margin-top:20px}dd{margin:6px 0;overflow-wrap:anywhere}small{color:#52636c}</style><h1>MEDGUARD Emergency Medical ID</h1><p>Owner-provided information. Confirm details when possible.</p><dl>${rows}</dl><small>Profile updated: ${escapeHtml(owner.updatedAt.toISOString())}. This link requires internet. Previously saved copies cannot be revoked.</small></html>`);
  } else {
    const records = await Record.find({ _id: { $in: grant.recordIds }, userId: grant.ownerId }).select('title recordType documentDate fileName');
    const links = records.map(record => `<li>${escapeHtml(record.title)} — <a href="./${escapeHtml(req.params.token)}/files/${record._id}">Download original</a></li>`).join('');
    res.type('html').send(`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MEDGUARD shared records</title><h1>Shared health records</h1><p>Private link. Downloads may be retained after access expires.</p><ul>${links}</ul></html>`);
  }
}));
router.get('/public/:token/files/:recordId', limited, wrap(async (req, res) => {
  if (!/^[A-Za-z0-9_-]{43}$/.test(req.params.token) || !id(req.params.recordId)) return res.sendStatus(404);
  const grant = await Grant.findOne({ tokenHash: hashToken(req.params.token), kind: 'vault' });
  if (!activeGrant(grant) || grant.recipientEmail || !grant.recordIds.some(value => String(value) === req.params.recordId)) return res.sendStatus(404);
  if (!await User.exists({ _id: grant.ownerId, isActive: true })) return res.sendStatus(404);
  const record = await Record.findOne({ _id: req.params.recordId, userId: grant.ownerId });
  if (!record || (process.env.NODE_ENV === 'production' && record.scan?.status !== 'clean')) return res.sendStatus(404);
  const { stream, fileName } = await storage.getDownloadStream(record);
  await audit(grant.ownerId, 'vault-share.download', grant._id);
  res.type('application/octet-stream');
  res.attachment(String(fileName).replace(/[\r\n]/g, ''));
  stream.on('error', () => { if (!res.headersSent) res.sendStatus(404); else res.destroy(); });
  stream.pipe(res);
}));

router.get('/deletion-status/:receipt', limited, wrap(async (req, res) => {
  if (!/^[A-Za-z0-9_-]{43}$/.test(req.params.receipt)) return res.sendStatus(404);
  const job = await require('../models/DeletionRequest').findOne({ receiptHash: hashToken(req.params.receipt) }).select('status createdAt completedAt');
  if (!job) return res.sendStatus(404);
  res.json({ success: true, status: job.status, requestedAt: job.createdAt, completedAt: job.completedAt });
}));

router.use(authenticateToken);
router.use(rateLimit({ windowMs: 60000, limit: Math.max(1, Math.min(1000, Number(process.env.LAUNCH_RATE_LIMIT) || 120)), standardHeaders: 'draft-8', legacyHeaders: false }));
router.get('/grants', wrap(async (req, res) => {
  const grants = await Grant.find({ $or: [{ ownerId: req.userId }, { recipientId: req.userId }] }).sort({ createdAt: -1 }).limit(200);
  res.json({ success: true, grants: grants.map(g => ({ ...g.toObject(), viewerRole: String(g.ownerId) === String(req.userId) ? 'owner' : 'recipient' })) });
}));
router.delete('/grants/:grantId', wrap(async (req, res) => {
  if (!id(req.params.grantId)) return res.sendStatus(404);
  const grant = await Grant.findOneAndUpdate({ _id: req.params.grantId, $or: [{ ownerId: req.userId }, { recipientId: req.userId }] }, { $set: { revokedAt: new Date() } }, { new: true });
  if (!grant) return res.sendStatus(404);
  await audit(grant.ownerId, 'grant.revoke', grant._id);
  res.json({ success: true });
}));
router.post('/grants', limited, wrap(async (req, res) => {
  const { kind, fields, recordIds, recipientEmail, permissions, consent } = req.body;
  if (!['medical-id', 'caregiver', 'vault'].includes(kind) || consent !== true) return invalid(res, 'Choose a sharing type and confirm explicit consent.');
  const days = req.body.expiresInDays ?? (kind === 'medical-id' ? 365 : 7);
  if (!Number.isInteger(days) || days < 1 || days > 365) return invalid(res, 'Expiry must be 1–365 days.');
  const data = { ownerId: req.userId, kind, expiresAt: new Date(Date.now() + days * 86400000) };
  if (kind === 'medical-id') {
    if (!Array.isArray(fields) || !fields.length || fields.length > medicalFields.length || fields.some(f => !medicalFields.includes(f))) return invalid(res, 'Select valid Medical ID fields.');
    data.fields = [...new Set(fields)];
  }
  if (kind === 'vault') {
    if (!Array.isArray(recordIds) || !recordIds.length || recordIds.length > 20 || recordIds.some(value => !id(value))) return invalid(res, 'Select 1–20 valid records.');
    data.recordIds = [...new Set(recordIds)];
    if (req.body.recipientEmail) {
      if (typeof req.body.recipientEmail !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(req.body.recipientEmail) || req.body.recipientEmail.length > 254) return invalid(res, 'Valid recipient account email required.');
      data.recipientEmail = req.body.recipientEmail.toLowerCase().trim();
    }
    if (process.env.NODE_ENV === 'production' && await Record.countDocuments({ _id: { $in: data.recordIds }, userId: req.userId, 'scan.status': 'clean' }) !== data.recordIds.length) return invalid(res, 'Every shared file must pass a malware scan. Re-scan legacy records first.');
    if (await Record.countDocuments({ _id: { $in: data.recordIds }, userId: req.userId }) !== data.recordIds.length) return res.sendStatus(404);
  }
  if (kind === 'caregiver') {
    if (req.user.age !== null && req.user.age < 18) return invalid(res, 'Caregiver account sharing requires an adult account. Manage dependent records through a guardian account.');
    if (typeof recipientEmail !== 'string' || recipientEmail.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipientEmail)) return invalid(res, 'Provide the caregiver account email.');
    if (recipientEmail.toLowerCase().trim() === req.user.email) return invalid(res, 'Invite a different account.');
    if (!Array.isArray(permissions) || !permissions.length || permissions.length > 3 || permissions.some(p => !['profile', 'medicines', 'appointments'].includes(p))) return invalid(res, 'Choose caregiver permissions.');
    data.recipientEmail = recipientEmail.toLowerCase().trim();
    data.permissions = [...new Set(permissions)];
  }
  const token = newToken();
  const grant = await Grant.create({ ...data, tokenHash: hashToken(token) });
  await audit(req.userId, `${kind}.create`, grant._id);
  // Return a relative URL: no Host-header-derived public URLs and no token persistence on clients.
  const result = grant.toObject(); delete result.tokenHash;
  res.status(201).json({ success: true, grant: result, token, publicPath: kind === 'caregiver' ? null : `/api/launch/public/${token}` });
}));

router.post('/caregiver/accept', limited, wrap(async (req, res) => {
  const { token } = req.body;
  if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) return invalid(res, 'Valid invitation code required.');
  const grant = await Grant.findOneAndUpdate({ kind: { $in: ['caregiver', 'vault'] }, tokenHash: hashToken(token), recipientEmail: req.user.email, recipientId: null, revokedAt: null, expiresAt: { $gt: new Date() } }, { $set: { recipientId: req.userId, acceptedAt: new Date() } }, { new: true });
  if (!grant) return res.status(404).json({ success: false, message: 'Invitation unavailable, already accepted, or intended for another account.' });
  await audit(req.userId, 'caregiver.accept', grant._id);
  res.json({ success: true, grant });
}));
router.get('/caregiver/:grantId/:scope', wrap(async (req, res) => {
  if (!id(req.params.grantId) || !['profile', 'medicines', 'appointments'].includes(req.params.scope)) return res.sendStatus(404);
  const grant = await Grant.findOne({ _id: req.params.grantId, kind: 'caregiver', recipientId: req.userId });
  if (!activeGrant(grant) || !grant.permissions.includes(req.params.scope)) return res.sendStatus(404);
  const owner = await User.findOne({ _id: grant.ownerId, isActive: true });
  if (!owner) return res.sendStatus(404);
  let data;
  if (req.params.scope === 'profile') data = projectMedical(owner, medicalFields);
  if (req.params.scope === 'medicines') data = await Medicine.find({ userId: owner._id, isActive: true }).select('name dosage times frequency remainingStock');
  if (req.params.scope === 'appointments') data = await Appointment.find({ userId: owner._id }).select('doctorName hospitalName appointmentDate appointmentTime status').limit(100);
  await audit(owner._id, `caregiver.read.${req.params.scope}`, grant._id);
  res.json({ success: true, ownerName: owner.fullName, scope: req.params.scope, data });
}));

const familyFields = ['name', 'relationship', 'dateOfBirth', 'gender', 'bloodGroup', 'noKnownAllergies', 'allergies', 'existingConditions', 'currentMedications', 'emergencyCountryCode', 'emergencyPhone', 'emergencyNotes'];
router.get('/family', wrap(async (req, res) => res.json({ success: true, members: await Family.find({ userId: req.userId }).sort({ name: 1 }) })));
router.put('/family/:clientId', wrap(async (req, res) => {
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(req.params.clientId)) return invalid(res, 'Invalid family record identifier.');
  const data = {};
  for (const field of familyFields) if (req.body[field] !== undefined) data[field] = req.body[field];
  if (typeof data.name !== 'string' || !data.name.trim() || typeof data.relationship !== 'string' || !data.relationship.trim() || typeof data.dateOfBirth !== 'string' || !Number.isFinite(Date.parse(data.dateOfBirth)) || new Date(data.dateOfBirth) > new Date()) return invalid(res, 'Valid name, relationship and birth date required.');
  for (const [key, value] of Object.entries(data)) if (key !== 'noKnownAllergies' && typeof value !== 'string') return invalid(res, 'Family fields must be plain text.');
  const age = (Date.now() - Date.parse(data.dateOfBirth)) / (365.2425 * 86400000);
  if (age < 18 && (req.body.guardianAcknowledged !== true || (req.user.age !== null && req.user.age < 18))) return invalid(res, 'An adult guardian must acknowledge responsibility before saving a minor dependent.');
  data.guardianAcknowledged = req.body.guardianAcknowledged === true;
  const member = await Family.findOneAndUpdate({ userId: req.userId, clientId: req.params.clientId }, { $set: data }, { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true });
  res.json({ success: true, member });
}));
router.delete('/family/:clientId', wrap(async (req, res) => {
  await Family.deleteOne({ userId: req.userId, clientId: req.params.clientId });
  res.json({ success: true });
}));
router.post('/privacy/export', limited, wrap(async (req, res) => {
  if (typeof req.body.password !== 'string' || req.body.password.length > 256 || !await req.user.comparePassword(req.body.password)) return res.status(403).json({ success: false, message: 'Confirm your current password.' });
  const collections = {
    medicines: Medicine, medicationLogs: require('../models/MedicationLog'), appointments: Appointment,
    healthRecords: Record, familyProfiles: Family, emergencyContacts: require('../models/EmergencyContact'),
    waterIntake: require('../models/WaterIntake'), bmiHistory: require('../models/BmiHistory'),
    notificationPreferences: require('../models/NotificationPreference'),
  };
  const exported = { schemaVersion: 1, exportedAt: new Date().toISOString(), profile: req.user.toJSON(), attachmentNotice: 'Original file bytes are downloaded separately from Health Vault.' };
  delete exported.profile.avatarGridFSId;
  for (const [key, model] of Object.entries(collections)) {
    exported[key] = await model.find({ userId: req.userId }).lean();
    for (const row of exported[key]) { delete row.storageKey; delete row.filePath; delete row.pdfPath; delete row.doseReceipts; }
  }
  await audit(req.userId, 'privacy.export', req.userId);
  res.json({ success: true, export: exported });
}));
router.get('/privacy', wrap(async (req, res) => {
  const [sessions, events] = await Promise.all([
    Session.find({ userId: req.userId, isActive: true, expiresAt: { $gt: new Date() } }).select('_id createdAt expiresAt'),
    Audit.find({ userId: req.userId }).sort({ createdAt: -1 }).limit(100).select('action details createdAt'),
  ]);
  res.json({ success: true, sessions, events, retention:{ activeStorage:'Deleted by retryable account cleanup', backupRetentionDays: /^[0-9]+$/.test(process.env.BACKUP_RETENTION_DAYS || '')?Number(process.env.BACKUP_RETENTION_DAYS):null, copiesNotice:'Recipients may retain previously downloaded copies.' } });
}));
router.delete('/privacy/sessions/:sessionId', wrap(async (req, res) => {
  if (!id(req.params.sessionId)) return res.sendStatus(404);
  await Session.updateOne({ _id: req.params.sessionId, userId: req.userId }, { $set: { isActive: false } });
  res.json({ success: true });
}));



router.post('/privacy/delete-account', limited, wrap(async (req, res) => {
  if (typeof req.body.password !== 'string' || !await req.user.comparePassword(req.body.password) || req.body.confirmation !== 'DELETE') return res.status(400).json({ success: false, message: 'Current password and DELETE confirmation required.' });
  const receipt = await require('../services/deletionService').requestDeletion(req.userId);
  res.status(202).json({ success: true, status: 'pending', receipt, message: 'Access disabled. Cleanup pending. Backups expire under the configured hosting retention policy; already shared copies cannot be recalled.' });
}));

router.post('/grants/:grantId/reissue', limited, wrap(async (req,res) => {
  if (!id(req.params.grantId)) return res.sendStatus(404);
  const old = await Grant.findOne({ _id:req.params.grantId, ownerId:req.userId });
  if (!activeGrant(old) || !old.recipientEmail) return res.sendStatus(404);
  // Explicit replacement revokes previously accepted access. Acceptance is required again.
  old.revokedAt=new Date(); await old.save();
  const token=newToken();
  const grant=await Grant.create({ ownerId:req.userId, kind:old.kind, recipientEmail:old.recipientEmail, permissions:old.permissions, recordIds:old.recordIds, expiresAt:old.expiresAt, tokenHash:hashToken(token) });
  await audit(req.userId,'grant.reissue',grant._id);
  const result=grant.toObject(); delete result.tokenHash;
  res.status(201).json({success:true,grant:result,token});
}));
async function recipientGrant(req) {
  if (!id(req.params.grantId)) return null;
  const grant=await Grant.findOne({_id:req.params.grantId,kind:'vault',recipientId:req.userId});
  if (!activeGrant(grant) || !grant.acceptedAt || !await User.exists({_id:grant.ownerId,isActive:true})) return null;
  return grant;
}
router.get('/vault/:grantId',wrap(async(req,res)=>{
  const grant=await recipientGrant(req); if(!grant) return res.sendStatus(404);
  const records=await Record.find({_id:{$in:grant.recordIds},userId:grant.ownerId}).select('title fileName mimeType fileSizeBytes');
  res.json({success:true,records});
}));
router.get('/vault/:grantId/files/:recordId',wrap(async(req,res)=>{
  const grant=await recipientGrant(req);
  if(!grant || !id(req.params.recordId) || !grant.recordIds.some(id=>String(id)===req.params.recordId)) return res.sendStatus(404);
  const record=await Record.findOne({_id:req.params.recordId,userId:grant.ownerId});
  if(!record || (process.env.NODE_ENV==='production' && record.scan?.status!=='clean')) return res.sendStatus(404);
  const {stream,fileName}=await storage.getDownloadStream(record);
  await audit(grant.ownerId,'vault-recipient.download',grant._id);
  res.attachment(String(fileName).replace(/[\r\n]/g,''));
  res.type('application/octet-stream');
  stream.on('error',()=>{if(!res.headersSent) res.sendStatus(404); else res.destroy();});stream.pipe(res);
}));
router.post('/vault/rescan/:recordId',limited,wrap(async(req,res)=>{
  if(!id(req.params.recordId)) return res.sendStatus(404);
  const record=await Record.findOne({_id:req.params.recordId,userId:req.userId});if(!record) return res.sendStatus(404);
  const {stream}=await storage.getDownloadStream(record);const parts=[];let size=0;
  for await (const chunk of stream) {size+=chunk.length;if(size>30*1024*1024) {stream.destroy();return invalid(res,'File too large to scan.');} parts.push(chunk);}
  record.scan={status:'unscanned',engine:'pending-rescan'};await record.save();
  record.scan=await require('../services/uploadSafety').inspectUpload({buffer:Buffer.concat(parts),originalname:record.fileName});
  await record.save();res.json({success:true,scan:record.scan});
}));
module.exports=router;
