const mongoose = require('mongoose');

const bmiHistorySchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  weightKg: {
    type: Number,
    required: true,
  },
  heightCm: {
    type: Number,
    required: true,
  },
  bmi: {
    type: Number,
    required: true,
  },
  category: {
    type: String,
    required: true, // Underweight, Normal, Overweight, Obese
  },
  calculatedAt: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('BmiHistory', bmiHistorySchema);
