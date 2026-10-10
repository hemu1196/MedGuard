const express = require('express');
const router = express.Router();
const wellnessController = require('../controllers/wellnessController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.use(authenticateToken);

router.get('/water', wellnessController.getWaterIntake);
router.post('/water', wellnessController.logWaterIntake);

router.get('/bmi', wellnessController.getBmiHistory);
router.post('/bmi', wellnessController.saveBmiRecord);

module.exports = router;
