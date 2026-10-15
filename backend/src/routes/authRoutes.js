const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');

const { uploadVault } = require('../services/storageService');

// Public routes
router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/reset-password', authController.resetPassword);
router.post('/firebase-migrate', authController.firebaseMigrate);
router.get('/:userId/avatar', authController.getAvatar);

// Authenticated routes
router.get('/me', authenticateToken, authController.getMe);
router.get('/profile', authenticateToken, authController.getMe);
router.get('/verify', authenticateToken, authController.getMe);
router.post('/refresh', authenticateToken, authController.refreshToken);
router.put('/profile', authenticateToken, authController.updateProfile);
router.patch('/profile', authenticateToken, authController.updateProfile);
router.post('/profile', authenticateToken, authController.updateProfile);
router.post('/logout', authenticateToken, authController.logout);

// Avatar management routes
router.post('/me/avatar', authenticateToken, uploadVault.single('avatar'), authController.uploadAvatar);
router.delete('/me/avatar', authenticateToken, authController.removeAvatar);
router.post('/profile/avatar', authenticateToken, uploadVault.single('avatar'), authController.uploadAvatar);
router.delete('/profile/avatar', authenticateToken, authController.removeAvatar);

module.exports = router;

