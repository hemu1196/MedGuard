const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'medguard_production_jwt_secret_key_2026_secure';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

/**
 * Generate a JWT for a user
 * @param {Object} payload - Data to encode (e.g. { userId, email, role })
 * @returns {string} token
 */
const generateToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
};

/**
 * Verify a JWT
 * @param {string} token
 * @returns {Object} decoded token payload
 */
const verifyToken = (token) => {
  return jwt.verify(token, JWT_SECRET);
};

module.exports = {
  generateToken,
  verifyToken,
};
