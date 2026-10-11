const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.use(authenticateToken);

// User profile endpoints (/api/users/me and /api/users/profile)
router.get('/me', authController.getMe);
router.patch('/me', authController.updateProfile);
router.put('/me', authController.updateProfile);
router.post('/me', authController.updateProfile);

router.get('/profile', authController.getMe);
router.patch('/profile', authController.updateProfile);
router.put('/profile', authController.updateProfile);
router.post('/profile', authController.updateProfile);

module.exports = router;
