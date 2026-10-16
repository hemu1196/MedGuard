const express = require('express');
const router = express.Router();
const healthRecordController = require('../controllers/healthRecordController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { uploadVault } = require('../services/storageService');

// All health vault routes require valid JWT bearer authentication
router.use(authenticateToken);

// Record listing and retrieval
router.get('/', healthRecordController.getRecords);
router.get('/:recordId', healthRecordController.getRecordById);

// Record creation and upload
router.post('/', healthRecordController.createRecord);
router.post('/upload', uploadVault.single('file'), healthRecordController.uploadRecord);

// Secure authenticated file download / view stream
router.get('/:recordId/download', healthRecordController.downloadRecord);
router.get('/download/:recordId', healthRecordController.downloadRecord);

// Record update (metadata and optional new file attachment)
router.patch('/:recordId', uploadVault.single('file'), healthRecordController.updateRecord);
router.put('/:recordId', uploadVault.single('file'), healthRecordController.updateRecord);

// Record deletion
router.delete('/:recordId', healthRecordController.deleteRecord);

module.exports = router;
