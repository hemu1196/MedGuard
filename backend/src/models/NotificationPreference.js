const mongoose = require('mongoose');

const notificationPreferenceSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true,
  },
  medicineReminders: {
    type: Boolean,
    default: true,
  },
  appointmentReminders: {
    type: Boolean,
    default: true,
  },
  waterReminders: {
    type: Boolean,
    default: true,
  },
  sosAlerts: {
    type: Boolean,
    default: true,
  },
  pushToken: {
    type: String,
    default: '',
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('NotificationPreference', notificationPreferenceSchema);
