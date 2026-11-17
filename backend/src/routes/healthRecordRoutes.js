const express = require('express');
const router = express.Router();
const healthRecordController = require('../controllers/healthRecordController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { rateLimit } = require('express-rate-limit');
const { uploadVault } = require('../services/storageService');

// All health vault routes require valid JWT bearer authentication
router.use(authenticateToken);

// Bound simultaneous in-memory 30 MB uploads before multipart parsing.
let inflightUploads = 0;
const uploadLimit = rateLimit({windowMs:60000,limit:20,standardHeaders:'draft-8',legacyHeaders:false});
function uploadCapacity(req,res,next) {
  if (inflightUploads >= 2) return res.status(503).json({success:false,message:'Uploads are busy. Please retry later.'});
  inflightUploads++;
  let released=false;
  const release=()=>{if(!released){released=true;inflightUploads--;}};
  res.once('finish',release);res.once('close',release);next();
}

// Record listing and retrieval
router.get('/', healthRecordController.getRecords);
router.get('/:recordId', healthRecordController.getRecordById);

// Record creation and upload
router.post('/', healthRecordController.createRecord);
router.post('/upload', uploadLimit, uploadCapacity, uploadVault.single('file'), healthRecordController.uploadRecord);

// Secure authenticated file download / view stream
router.get('/:recordId/download', healthRecordController.downloadRecord);
router.get('/download/:recordId', healthRecordController.downloadRecord);

// Record update (metadata and optional new file attachment)
router.patch('/:recordId', uploadLimit, uploadCapacity, uploadVault.single('file'), healthRecordController.updateRecord);
router.put('/:recordId', uploadLimit, uploadCapacity, uploadVault.single('file'), healthRecordController.updateRecord);

// Record deletion
router.delete('/:recordId', healthRecordController.deleteRecord);

module.exports = router;
