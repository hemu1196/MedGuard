const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { Readable } = require('stream');
const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const UPLOADS_DIR = path.join(__dirname, '../../uploads');
const VAULT_DIR = path.join(UPLOADS_DIR, 'vault');
const PDFS_DIR = path.join(UPLOADS_DIR, 'pdfs');

// Ensure local fallback directories exist
[UPLOADS_DIR, VAULT_DIR, PDFS_DIR].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Memory storage for direct persistent cloud streaming without ephemeral file loss
const memoryStorage = multer.memoryStorage();

const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/jpg',
  'image/webp',
  'image/gif',
  'image/bmp',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
  'text/csv',
];

const ALLOWED_EXTENSIONS = [
  '.pdf',
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.bmp',
  '.doc',
  '.docx',
  '.txt',
  '.csv',
];

function resolveMimeType(file) {
  if (file.mimetype && file.mimetype !== 'application/octet-stream' && ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    return file.mimetype;
  }
  const ext = path.extname(file.originalname || '').toLowerCase();
  switch (ext) {
    case '.pdf':
      return 'application/pdf';
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.bmp':
      return 'image/bmp';
    case '.doc':
      return 'application/msword';
    case '.docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case '.txt':
      return 'text/plain';
    case '.csv':
      return 'text/csv';
    default:
      return file.mimetype || 'application/octet-stream';
  }
}

const uploadVault = multer({
  storage: memoryStorage,
  limits: { fileSize: 30 * 1024 * 1024 }, // 30 MB max
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const isMimeAllowed = ALLOWED_MIME_TYPES.includes(file.mimetype);
    const isExtAllowed = ALLOWED_EXTENSIONS.includes(ext);

    if (isMimeAllowed || isExtAllowed) {
      cb(null, true);
    } else {
      cb(
        new Error(
          'Invalid file type. Supported formats: PDF, PNG, JPG, JPEG, WEBP, DOC, DOCX, TXT.'
        )
      );
    }
  },
});

function getGridFSBucket() {
  if (!mongoose.connection.db) {
    throw new Error('Database connection is not yet ready for file operations.');
  }
  return new mongoose.mongo.GridFSBucket(mongoose.connection.db, {
    bucketName: 'vault_files',
  });
}

/**
 * Uploads file buffer to permanent private storage in MongoDB Atlas GridFS
 */
async function uploadToVault({ file, userId, title }) {
  if (!file || !file.buffer) {
    throw new Error('No valid file payload received for upload.');
  }

  const mimeType = resolveMimeType(file);
  const originalName = file.originalname || 'document.pdf';
  const ext = path.extname(originalName) || (mimeType.includes('pdf') ? '.pdf' : '.jpg');
  const safeBase = (title || path.basename(originalName, ext))
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/\s+/g, '_');
  const storedFileName = `${safeBase}_${uuidv4().substring(0, 8)}${ext}`;

  const bucket = getGridFSBucket();
  const uploadStream = bucket.openUploadStream(storedFileName, {
    contentType: mimeType,
    metadata: {
      userId: userId ? userId.toString() : null,
      originalName,
      title: title || originalName,
      uploadedAt: new Date(),
    },
  });

  const readStream = Readable.from(file.buffer);

  await new Promise((resolve, reject) => {
    readStream.pipe(uploadStream).on('finish', resolve).on('error', reject);
  });

  return {
    storageKey: uploadStream.id.toString(),
    storageType: 'gridfs',
    fileName: originalName,
    storedFileName,
    mimeType,
    fileSizeBytes: file.size || file.buffer.length,
  };
}

/**
 * Retrieves a readable stream for a stored health vault file
 */
async function getDownloadStream(record) {
  if (record.storageKey && (record.storageType === 'gridfs' || !record.storageType)) {
    const bucket = getGridFSBucket();
    const objectId = new mongoose.Types.ObjectId(record.storageKey);

    const files = await bucket.find({ _id: objectId }).toArray();
    if (!files || files.length === 0) {
      throw new Error('The requested file is no longer available in cloud storage.');
    }

    const stream = bucket.openDownloadStream(objectId);
    return {
      stream,
      mimeType: record.mimeType || files[0].contentType || 'application/octet-stream',
      fileName: record.fileName || files[0].filename,
      fileSizeBytes: record.fileSizeBytes || files[0].length,
    };
  }

  // Fallback for legacy records stored on server filesystem
  if (record.filePath && fs.existsSync(record.filePath)) {
    const stream = fs.createReadStream(record.filePath);
    return {
      stream,
      mimeType: record.mimeType || 'application/octet-stream',
      fileName: record.fileName || path.basename(record.filePath),
      fileSizeBytes: record.fileSizeBytes || fs.statSync(record.filePath).size,
    };
  }

  throw new Error('File content missing from persistent storage.');
}

/**
 * Permanently deletes file content from cloud storage
 */
async function deleteFromVault(record) {
  if (record.storageKey && (record.storageType === 'gridfs' || !record.storageType)) {
    try {
      const bucket = getGridFSBucket();
      await bucket.delete(new mongoose.Types.ObjectId(record.storageKey));
    } catch (err) {
      console.warn('[STORAGE] GridFS delete note:', err.message);
    }
  }

  if (record.filePath && fs.existsSync(record.filePath)) {
    try {
      fs.unlinkSync(record.filePath);
    } catch (err) {
      console.warn('[STORAGE] Local file unlink note:', err.message);
    }
  }
}

module.exports = {
  UPLOADS_DIR,
  VAULT_DIR,
  PDFS_DIR,
  uploadVault,
  uploadToVault,
  getDownloadStream,
  deleteFromVault,
  resolveMimeType,
  getGridFSBucket,
};
