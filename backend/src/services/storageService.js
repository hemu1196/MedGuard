const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');

const UPLOADS_DIR = path.join(__dirname, '../../uploads');
const VAULT_DIR = path.join(UPLOADS_DIR, 'vault');
const PDFS_DIR = path.join(UPLOADS_DIR, 'pdfs');

// Ensure upload directories exist
[UPLOADS_DIR, VAULT_DIR, PDFS_DIR].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

const vaultStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, VAULT_DIR);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const uniqueName = `${uuidv4()}${ext}`;
    cb(null, uniqueName);
  },
});

const uploadVault = multer({
  storage: vaultStorage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB max
  fileFilter: (req, file, cb) => {
    // Allow images, PDFs, medical documents
    const allowedMimeTypes = [
      'image/jpeg', 'image/png', 'image/jpg', 'image/webp',
      'application/pdf', 'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
    ];
    if (allowedMimeTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only images, PDFs, and text documents are allowed.'));
    }
  },
});

module.exports = {
  UPLOADS_DIR,
  VAULT_DIR,
  PDFS_DIR,
  uploadVault,
};
