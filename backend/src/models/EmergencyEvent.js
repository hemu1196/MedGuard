const mongoose = require('mongoose');

const emergencyEventSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  triggerType: {
    type: String,
    enum: ['voice', 'manual', 'shake'],
    required: true,
  },
  location: {
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    address: { type: String, default: '' },
  },
  contactsNotified: [{
    contactId: { type: mongoose.Schema.Types.ObjectId, ref: 'EmergencyContact' },
    name: { type: String },
    phone: { type: String },
    status: { type: String, enum: ['pending', 'sent', 'failed'], default: 'sent' },
  }],
  status: {
    type: String,
    enum: ['active', 'resolved', 'cancelled'],
    default: 'active',
  },
  triggeredAt: {
    type: Date,
    default: Date.now,
  },
  resolvedAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('EmergencyEvent', emergencyEventSchema);
