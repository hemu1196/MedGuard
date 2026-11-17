const mongoose = require('mongoose');
const fs = require('node:fs/promises');
const path = require('node:path');
const Request = require('../models/DeletionRequest');
const Grant = require('../models/AccessGrant');
const User = require('../models/User');
const Session = require('../models/UserSession');
const { hashToken } = require('./accessPolicy');

async function requestDeletion(userId) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('Deletion signing secret unavailable.');
  const token = require('node:crypto').createHmac('sha256', secret).update('medguard-deletion:' + userId).digest('base64url');
  await Request.findOneAndUpdate({ userId }, { $setOnInsert: { receiptHash: hashToken(token), status: 'pending' } }, { upsert: true, new: true });
  // Worker repeats these operations after a crash or a partially completed request.
  await User.updateOne({ _id: userId }, { $set: { isActive: false } });
  await Session.updateMany({ userId }, { $set: { isActive: false } });
  await Grant.updateMany({ $or: [{ ownerId: userId }, { recipientId: userId }] }, { $set: { revokedAt: new Date() } });
  return token;
}
async function deleteBucketFiles(bucketName, userId) {
  const bucket = new mongoose.mongo.GridFSBucket(mongoose.connection.db, { bucketName });
  const files = await bucket.find({ 'metadata.userId': String(userId) }).toArray();
  for (const file of files) {
    // Deleting chunks + file metadata explicitly is idempotent after partial failures.
    await mongoose.connection.db.collection(bucketName + '.chunks').deleteMany({ files_id: file._id });
    await mongoose.connection.db.collection(bucketName + '.files').deleteOne({ _id: file._id });
  }
}
async function processOneDeletion() {
  if (mongoose.connection.readyState !== 1) return false;
  const now = new Date();
  const job = await Request.findOneAndUpdate({ status: { $ne: 'complete' }, $or: [{ leaseUntil: null }, { leaseUntil: { $lt: now } }] }, { $set: { status: 'processing', leaseUntil: new Date(Date.now() + 300000) }, $inc: { attempts: 1 } }, { new: true });
  if (!job) return false;
  try {
    await User.updateOne({ _id: job.userId }, { $set: { isActive: false } });
    await Session.updateMany({ userId: job.userId }, { $set: { isActive: false } });
    await Grant.updateMany({ $or: [{ ownerId: job.userId }, { recipientId: job.userId }] }, { $set: { revokedAt: now } });
    // Legacy originals and generated appointment PDFs may predate GridFS.
    const uploadsRoot = path.resolve(__dirname, '../../uploads');
    const records = await require('../models/HealthRecord').find({ userId: job.userId }).select('filePath');
    const appointments = await require('../models/Appointment').find({ userId: job.userId }).select('pdfPath');
    for (const filePath of [...records.map(r => r.filePath), ...appointments.map(a => a.pdfPath)].filter(Boolean)) {
      const absolute = path.resolve(filePath);
      if (!absolute.startsWith(uploadsRoot + path.sep)) throw new Error('Legacy file requires operator cleanup.');
      await fs.rm(absolute, { force: true });
    }
    await deleteBucketFiles('vault_files', job.userId);
    await deleteBucketFiles('avatars', job.userId);
    for (const modelName of ['Medicine', 'MedicationLog', 'Appointment', 'HealthRecord', 'WaterIntake', 'BmiHistory', 'EmergencyContact', 'EmergencyEvent', 'NotificationPreference', 'UserSession', 'PasswordReset', 'FamilyProfile', 'AuditEvent']) {
      const Model = require('../models/' + modelName);
      await Model.deleteMany({ userId: job.userId });
    }
    await Grant.deleteMany({ $or: [{ ownerId: job.userId }, { recipientId: job.userId }] });
    await User.deleteOne({ _id: job.userId });
    await Request.updateOne({ _id: job._id }, { $set: { status: 'complete', completedAt: new Date(), leaseUntil: null } });
    return true;
  } catch (_) {
    await Request.updateOne({ _id: job._id }, { $set: { status: 'pending', leaseUntil: new Date(Date.now() + 60000) } });
    // No sensitive payloads or exception messages in operational logs.
    console.error('[DELETION] Cleanup will retry.');
    return false;
  }
}
let running = false;
function startDeletionWorker() {
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try { await processOneDeletion(); } catch (_) { console.error('[DELETION] Worker unavailable.'); }
    finally { running = false; }
  }, 30000);
  timer.unref();
  return timer;
}
module.exports = { requestDeletion, processOneDeletion, startDeletionWorker };
