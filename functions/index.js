const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

const otpCollection = 'password_reset_otps';

function emailDocId(email) {
  return email.trim().toLowerCase().replace(/\./g, ',');
}

exports.completeEmailPasswordReset = onCall(async (request) => {
  const email = (request.data.email || '').trim().toLowerCase();
  const newPassword = String(request.data.newPassword || '');

  if (!email || !email.includes('@')) {
    throw new HttpsError('invalid-argument', 'Valid email is required.');
  }
  if (newPassword.length < 8) {
    throw new HttpsError('invalid-argument', 'Password must be at least 8 characters.');
  }

  const db = getFirestore();
  const docRef = db.collection(otpCollection).doc(emailDocId(email));
  const snap = await docRef.get();

  if (!snap.exists) {
    throw new HttpsError('failed-precondition', 'Code expired. Please request a new one.');
  }

  const session = snap.data();
  if (!session.verified) {
    throw new HttpsError('failed-precondition', 'Code expired. Please request a new one.');
  }

  const resetExpires =
    session.passwordResetExpiresAt?.toDate?.() || session.expiresAt?.toDate?.();
  if (!resetExpires || resetExpires < new Date()) {
    throw new HttpsError('failed-precondition', 'Code expired. Please request a new one.');
  }

  const sessionEmail = (session.email || '').trim().toLowerCase();
  if (sessionEmail !== email) {
    throw new HttpsError('permission-denied', 'Invalid reset session.');
  }

  const auth = getAuth();
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
  } catch {
    throw new HttpsError('not-found', 'No CareLanka account found with this email.');
  }

  await auth.updateUser(userRecord.uid, { password: newPassword });
  await docRef.delete();

  return { ok: true };
});
