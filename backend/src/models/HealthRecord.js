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
    enum: ['lab', 'prescription', 'scan', 'other'],
    default: 'other',
  },
  filePath: {
    type: String,
    required: true,
  },
  fileName: {
    type: String,
    required: true,
  },
  mimeType: {
    type: String,
    required: true,
  },
  fileSizeBytes: {
    type: Number,
    required: true,
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
