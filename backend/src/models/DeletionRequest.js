const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true, unique: true },
  receiptHash: { type: String, required: true, unique: true, select: false },
  status: { type: String, enum: ['pending', 'processing', 'complete'], default: 'pending' },
  attempts: { type: Number, default: 0 },
  leaseUntil: { type: Date, default: null },
  completedAt: { type: Date, default: null },
}, { timestamps: true });
module.exports = mongoose.model('DeletionRequest', schema);
