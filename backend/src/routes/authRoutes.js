const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Public routes
router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/reset-password', authController.resetPassword);
router.post('/firebase-migrate', authController.firebaseMigrate);

// Authenticated routes
router.get('/me', authenticateToken, authController.getMe);
router.get('/profile', authenticateToken, authController.getMe);
router.get('/verify', authenticateToken, authController.getMe);
router.post('/refresh', authenticateToken, authController.refreshToken);
router.put('/profile', authenticateToken, authController.updateProfile);
router.patch('/profile', authenticateToken, authController.updateProfile);
router.post('/profile', authenticateToken, authController.updateProfile);
router.post('/logout', authenticateToken, authController.logout);

module.exports = router;
