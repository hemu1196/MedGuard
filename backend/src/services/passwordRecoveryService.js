const { randomBytes, createHash } = require('node:crypto');
const nodemailer = require('nodemailer');
const PasswordReset = require('../models/PasswordReset');

const hashToken = (token) => createHash('sha256').update(token).digest('hex');
function getTransport() {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASSWORD || !process.env.MAIL_FROM) {
    const error = new Error('Password recovery email is not configured. Contact support.');
    error.status = 503;
    throw error;
  }
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_PORT === '465',
    requireTLS: true,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASSWORD },
    connectionTimeout: 10000,
    socketTimeout: 15000,
  });
}
async function sendReset(user, transport) {
  const token = randomBytes(24).toString('hex');
  const tokenHash = hashToken(token);
  await PasswordReset.findOneAndUpdate({ userId: user._id }, {
    tokenHash, expiresAt: new Date(Date.now() + 15 * 60 * 1000),
  }, { upsert: true });
  try {
    await transport.sendMail({
      from: process.env.MAIL_FROM,
      to: user.email,
      subject: 'MEDGUARD password recovery',
      text: `Enter this recovery code in MEDGUARD to set your new password:\n\n${token}\n\nThis code expires in 15 minutes and can be used once. If you did not request this, ignore this email.`,
    });
  } catch (error) {
    await PasswordReset.deleteOne({ userId: user._id, tokenHash });
    throw error;
  }
}
module.exports = { hashToken, getTransport, sendReset };
