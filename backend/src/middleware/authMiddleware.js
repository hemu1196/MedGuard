const { createHash } = require('node:crypto');
const { verifyToken } = require('../utils/jwt');
const User = require('../models/User');
const UserSession = require('../models/UserSession');

const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required. No token provided.',
      });
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);

    const tokenHash = createHash('sha256').update(token).digest('hex');
    const session = await UserSession.findOne({ $or:[{tokenHash},{token}], userId: decoded.userId, isActive: true, expiresAt: { $gt: new Date() } }).select('+tokenHash');
    if (!session) return res.status(401).json({ success: false, message: 'Session expired or revoked. Please sign in again.' });
    const user = await User.findById(decoded.userId);
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Invalid token or user account disabled.',
      });
    }

    // In-place additive migration: retire legacy clear token after valid authentication.
    if (!session.tokenHash) await UserSession.updateOne({_id:session._id},{$set:{tokenHash},$unset:{token:''}});
    req.user = user;
    req.userId = user._id;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Token expired. Please login again.',
      });
    }
    return res.status(401).json({
      success: false,
      message: 'Invalid authentication token.',
    });
  }
};

module.exports = {
  authenticateToken,
};
