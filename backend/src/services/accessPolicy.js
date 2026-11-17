const crypto = require('crypto');
const medicalFields = ['fullName', 'bloodGroup', 'allergies', 'chronicConditions', 'emergencyMedicalInfo', 'emergencyContactName', 'emergencyCountryCode', 'emergencyPhone'];
function hashToken(token) { return crypto.createHash('sha256').update(token).digest('hex'); }
function newToken() { return crypto.randomBytes(32).toString('base64url'); }
function projectMedical(user, fields) {
  const result = {};
  for (const field of fields) if (medicalFields.includes(field)) result[field] = user[field];
  return result;
}
function activeGrant(grant, now = new Date()) {
  return Boolean(grant && !grant.revokedAt && new Date(grant.expiresAt) > now);
}
function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
module.exports = { medicalFields, hashToken, newToken, projectMedical, activeGrant, escapeHtml };
