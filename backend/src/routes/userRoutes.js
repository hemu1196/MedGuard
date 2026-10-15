const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { uploadVault } = require('../services/storageService');

// Public avatar streaming endpoints (allows standard Image.network/browser requests without auth token)
router.get('/:userId/avatar', authController.getAvatar);
router.get('/avatar/:userId', authController.getAvatar);

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

// Avatar management endpoints
router.post('/me/avatar', uploadVault.single('avatar'), authController.uploadAvatar);
router.delete('/me/avatar', authController.removeAvatar);
router.post('/avatar', uploadVault.single('avatar'), authController.uploadAvatar);
router.delete('/avatar', authController.removeAvatar);
router.post('/profile/avatar', uploadVault.single('avatar'), authController.uploadAvatar);
router.delete('/profile/avatar', authController.removeAvatar);

module.exports = router;

