const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  kind: { type: String, enum: ['medical-id', 'caregiver', 'vault'], required: true },
  tokenHash: { type: String, required: true, unique: true, select: false },
  recipientEmail: { type: String, default: '', lowercase: true, trim: true },
  recipientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  permissions: [{ type: String, enum: ['profile', 'medicines', 'appointments'] }],
  recordIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'HealthRecord' }],
  fields: [{ type: String }],
  expiresAt: { type: Date, required: true },
  acceptedAt: { type: Date, default: null },
  revokedAt: { type: Date, default: null },
}, { timestamps: true });
schema.index({ ownerId: 1, kind: 1, revokedAt: 1 });
module.exports = mongoose.model('AccessGrant', schema);
