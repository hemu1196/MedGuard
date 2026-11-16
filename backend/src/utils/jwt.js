const jwt = require('jsonwebtoken');
const { randomUUID } = require('node:crypto');

function getSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error('JWT_SECRET must be configured with at least 32 characters.');
  }
  return secret;
}

const generateToken = (payload) => jwt.sign(payload, getSecret(), {
  algorithm: 'HS256',
  expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  jwtid: randomUUID(),
});
const verifyToken = (token) => jwt.verify(token, getSecret(), { algorithms: ['HS256'] });
module.exports = { generateToken, verifyToken, getSecret };
