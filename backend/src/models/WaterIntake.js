const mongoose = require('mongoose');

const waterIntakeSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  date: {
    type: String, // YYYY-MM-DD
    required: true,
  },
  targetMl: {
    type: Number,
    default: 2000,
  },
  consumedMl: {
    type: Number,
    default: 0,
  },
  logs: [{
    time: { type: String }, // HH:mm
    amountMl: { type: Number, required: true },
    timestamp: { type: Date, default: Date.now },
  }],
}, {
  timestamps: true,
});

waterIntakeSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('WaterIntake', waterIntakeSchema);
