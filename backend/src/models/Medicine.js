const mongoose = require('mongoose');

const medicineSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  name: {
    type: String,
    required: true,
    trim: true,
  },
  dosage: {
    type: String,
    required: true,
    trim: true,
  },
  times: [{
    type: String, // HH:mm format, e.g. "08:00"
  }],
  frequency: {
    type: String,
    default: 'Daily',
  },
  totalStock: {
    type: Number,
    default: 0,
  },
  remainingStock: {
    type: Number,
    default: 0,
  },
  instructions: {
    type: String,
    default: '',
  },
  startDate: {
    type: Date,
    default: Date.now,
  },
  endDate: {
    type: Date,
    default: null,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Medicine', medicineSchema);
