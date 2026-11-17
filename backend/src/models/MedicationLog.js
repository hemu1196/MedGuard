const mongoose = require('mongoose');

const medicationLogSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  medicineId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Medicine',
    required: true,
    index: true,
  },
  medicineName: {
    type: String,
    required: true,
  },
  dosage: {
    type: String,
    default: '',
  },
  occurrenceId: { type: String },
  scheduledDate: { type: String },
  scheduledTime: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    enum: ['taken', 'skipped', 'missed'],
    required: true,
  },
  takenAt: {
    type: Date,
    default: null,
  },
  missedReason: {
    type: String,
    default: '',
  },
}, {
  timestamps: true,
});

medicationLogSchema.index({ userId: 1, occurrenceId: 1 }, { unique: true, partialFilterExpression: { occurrenceId: { $type: 'string' } } });

module.exports = mongoose.model('MedicationLog', medicationLogSchema);
