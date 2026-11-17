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
  weekdays: [{ type:Number, min:1, max:7 }],
  dosageQuantity: { type:Number, min:1, max:10000, validate:Number.isInteger, default:1 },
  refillThreshold: { type:Number, min:0, max:1000000, validate:Number.isInteger, default:5 },
  scheduleVersion: { type: Number, default: 1 },
  doseCorrections: [{_id:false,operationId:String,occurrenceId:String,fromStatus:String,toStatus:String,reason:String,at:Date}],
  doseReceipts: [{ _id: false, occurrenceId: String, status: String, stockDebited:Number, originalStatus:String, at: Date }],
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Medicine', medicineSchema);
