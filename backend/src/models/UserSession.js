const mongoose = require('mongoose');

const userSessionSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  // Legacy clear tokens are read only for compatibility and removed on use.
  token: { type: String, select: false },
  tokenHash: { type: String, select: false, index: true },
  deviceInfo: {
    type: String,
    default: '',
  },
  ipAddress: {
    type: String,
    default: '',
  },
  expiresAt: {
    type: Date,
    required: true,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('UserSession', userSessionSchema);
