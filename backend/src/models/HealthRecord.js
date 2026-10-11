const mongoose = require('mongoose');

const healthRecordSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  title: {
    type: String,
    required: true,
    trim: true,
  },
  category: {
    type: String,
    default: 'other',
  },
  recordType: {
    type: String,
    default: 'other',
  },
  doctorName: {
    type: String,
    default: '',
    trim: true,
  },
  hospitalName: {
    type: String,
    default: '',
    trim: true,
  },
  documentDate: {
    type: Date,
    default: Date.now,
  },
  filePath: {
    type: String,
    default: null,
  },
  fileName: {
    type: String,
    default: '',
  },
  mimeType: {
    type: String,
    default: '',
  },
  fileSizeBytes: {
    type: Number,
    default: 0,
  },
  tags: [{
    type: String,
  }],
  notes: {
    type: String,
    default: '',
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('HealthRecord', healthRecordSchema);
