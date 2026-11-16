const { getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
async function verifyIdentity(idToken) {
  if (typeof idToken !== 'string' || !idToken) {
    const error = new Error('A verified Firebase ID token is required.');
    error.status = 401;
    throw error;
  }
  const projectId = process.env.FIREBASE_PROJECT_ID || 'medguard-ai-8e484';
  const app = getApps().find((app) => app.name === 'medguard-identity') ||
    initializeApp({ projectId }, 'medguard-identity');
  try {
    const identity = await getAuth(app).verifyIdToken(idToken);
    if (!identity.email || !identity.email_verified) throw new Error('Email verification required.');
    return identity;
  } catch (_) {
    const error = new Error('Firebase identity or verified email is invalid.');
    error.status = 401;
    throw error;
  }
}
module.exports = { verifyIdentity };
