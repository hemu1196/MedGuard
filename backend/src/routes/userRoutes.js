const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.use(authenticateToken);

// GET /api/users/me
router.get('/me', authController.getMe);

// PATCH /api/users/me
router.patch('/me', authController.updateProfile);

// PUT /api/users/me
router.put('/me', authController.updateProfile);

module.exports = router;
