const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  clientId: { type: String, required: true, maxlength: 100 },
  name: { type: String, required: true, trim: true, maxlength: 120 },
  relationship: { type: String, required: true, maxlength: 80 },
  dateOfBirth: { type: Date, required: true },
  gender: { type: String, maxlength: 40, default: '' },
  bloodGroup: { type: String, maxlength: 20, default: 'Unknown' },
  guardianAcknowledged: { type: Boolean, default: false },
  noKnownAllergies: { type: Boolean, default: false },
  allergies: { type: String, maxlength: 2000, default: '' },
  existingConditions: { type: String, maxlength: 2000, default: '' },
  currentMedications: { type: String, maxlength: 2000, default: '' },
  emergencyCountryCode: { type: String, maxlength: 8, default: '+91' },
  emergencyPhone: { type: String, maxlength: 24, default: '' },
  emergencyNotes: { type: String, maxlength: 2000, default: '' },
}, { timestamps: true });
schema.index({ userId: 1, clientId: 1 }, { unique: true });
schema.methods.toJSON = function () {
  const obj = this.toObject();
  obj.id = obj.clientId;
  obj.lastHealthUpdate = obj.updatedAt;
  obj.lastMedicineStatus = 'Not linked to a medicine schedule';
  return obj;
};
module.exports = mongoose.model('FamilyProfile', schema);
