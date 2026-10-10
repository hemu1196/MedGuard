const express = require('express');
const router = express.Router();
const aiAssistantController = require('../controllers/aiAssistantController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.use(authenticateToken);

router.post('/chat', aiAssistantController.chat);
router.post('/risk-assessment', aiAssistantController.assessHealthRisk);

module.exports = router;
