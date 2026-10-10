const express = require('express');
const router = express.Router();
const healthRecordController = require('../controllers/healthRecordController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { uploadVault } = require('../services/storageService');

router.use(authenticateToken);

router.get('/', healthRecordController.getRecords);
router.post('/upload', uploadVault.single('file'), healthRecordController.uploadRecord);
router.get('/download/:recordId', healthRecordController.downloadRecord);
router.delete('/:recordId', healthRecordController.deleteRecord);

module.exports = router;
