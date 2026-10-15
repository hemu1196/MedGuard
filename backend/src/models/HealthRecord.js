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
  storageKey: {
    type: String,
    default: null,
    index: true,
  },
  storageType: {
    type: String,
    enum: ['gridfs', 's3', 'local', 'none'],
    default: 'gridfs',
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

healthRecordSchema.methods.toJSON = function () {
  const obj = this.toObject();

  // Add aliases for frontend compatibility
  obj.id = obj._id ? obj._id.toString() : undefined;
  obj.documentType = obj.recordType || obj.category;
  obj.originalFileName = obj.fileName;
  obj.fileSize = obj.fileSizeBytes;

  // Provide download endpoint if storage key or file path is present
  if (obj.storageKey || (obj.filePath && obj.filePath.length > 0)) {
    obj.fileUrl = `/api/health-records/${obj._id}/download`;
  } else {
    obj.fileUrl = null;
  }

  return obj;
};

module.exports = mongoose.model('HealthRecord', healthRecordSchema);
