/**
 * CareLanka Medication Reminder Backend
 * ─────────────────────────────────────
 * Node.js + Express + node-cron + Firebase Admin SDK (FCM)
 *
 * Deploy to Render.com (free tier):
 *   Build command : npm install
 *   Start command : node server.js
 *   Environment   : NODE_VERSION = 20
 *
 * Required environment variables (set in Render dashboard):
 *   FIREBASE_SERVICE_ACCOUNT_JSON  — full contents of your serviceAccountKey.json
 *   PORT                           — set automatically by Render (default 10000)
 */

'use strict';

// ─── Core imports ────────────────────────────────────────────────────────────
const express  = require('express');
const cron     = require('node-cron');
const admin    = require('firebase-admin');

// ─── Firebase Admin initialisation ───────────────────────────────────────────
(function initFirebase() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    console.error('[FATAL] FIREBASE_SERVICE_ACCOUNT_JSON env var is missing.');
    process.exit(1);
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(raw);
  } catch (err) {
    console.error('[FATAL] Could not parse FIREBASE_SERVICE_ACCOUNT_JSON:', err.message);
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log('[Firebase] Admin SDK initialised ✅');
})();

// ─── In-memory reminder queue ─────────────────────────────────────────────────
//
// Each entry shape:
// {
//   id            : String  (unique queue entry id — "userId_medicationId_HH:MM")
//   userId        : String
//   medicationId  : String
//   medicationName: String
//   dosage        : String
//   condition     : String
//   scheduledTime : String  ("HH:MM" 24-hour, local server time)
//   fcmToken      : String
//   createdAt     : Date
//   firedToday    : Boolean (reset each day at midnight)
//   lastFiredAt   : Date | null
// }

/** @type {Map<string, object>} */
const reminderQueue = new Map();

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Returns current HH and MM as integers based on server local time. */
function nowHHMM() {
  const d = new Date();
  return { h: d.getHours(), m: d.getMinutes() };
}

/** Parse "HH:MM" → { h, m } or null on failure. */
function parseHHMM(str) {
  if (typeof str !== 'string') return null;
  const match = str.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const h = parseInt(match[1], 10);
  const m = parseInt(match[2], 10);
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return { h, m };
}

/** Build a unique queue ID from user + medication + time. */
function buildQueueId(userId, medicationId, scheduledTime) {
  return `${userId}_${medicationId}_${scheduledTime.trim()}`;
}

/** Send an FCM data + notification message to a single token. */
async function sendFCM({ fcmToken, medicationName, dosage, condition, userId, medicationId, scheduledTime }) {
  const bodyParts = [medicationName];
  if (dosage)    bodyParts.push(dosage);
  if (condition) bodyParts.push(`— ${condition}`);

  const message = {
    token: fcmToken,
    notification: {
      title: 'Time for your medication 💊',
      body:  bodyParts.join(' '),
    },
    data: {
      type:           'medication_reminder',
      userId:         userId,
      medicationId:   medicationId,
      medicationName: medicationName,
      dosage:         dosage         || '',
      condition:      condition       || '',
      scheduledTime:  scheduledTime,
    },
    android: {
      priority: 'high',
      notification: {
        channelId:    'carelanka_medication_channel',
        priority:     'max',
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: 'Time for your medication 💊',
            body:  bodyParts.join(' '),
          },
          sound:            'default',
          badge:            1,
          'interruption-level': 'time-sensitive',
        },
      },
    },
  };

  const response = await admin.messaging().send(message);
  return response; // message ID string
}

// ─── Express app ──────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());

// ── POST /schedule-medication ─────────────────────────────────────────────────
/**
 * Body: {
 *   userId, medicationId, medicationName,
 *   dosage, condition, scheduledTime ("HH:MM"),
 *   fcmToken
 * }
 */
app.post('/schedule-medication', (req, res) => {
  const {
    userId,
    medicationId,
    medicationName,
    dosage    = '',
    condition = '',
    scheduledTime,
    fcmToken,
  } = req.body || {};

  // ── Validation ────────────────────────────────────────────────────────────
  const missing = [];
  if (!userId)         missing.push('userId');
  if (!medicationId)   missing.push('medicationId');
  if (!medicationName) missing.push('medicationName');
  if (!scheduledTime)  missing.push('scheduledTime');
  if (!fcmToken)       missing.push('fcmToken');

  if (missing.length) {
    console.warn(`[POST /schedule-medication] Missing fields: ${missing.join(', ')}`);
    return res.status(400).json({ error: 'Missing required fields', missing });
  }

  const parsed = parseHHMM(scheduledTime);
  if (!parsed) {
    console.warn(`[POST /schedule-medication] Invalid scheduledTime: "${scheduledTime}"`);
    return res.status(400).json({ error: 'scheduledTime must be in HH:MM (24-hour) format' });
  }

  // ── Queue entry ───────────────────────────────────────────────────────────
  const queueId = buildQueueId(userId, medicationId, scheduledTime);
  const isUpdate = reminderQueue.has(queueId);

  reminderQueue.set(queueId, {
    id:             queueId,
    userId,
    medicationId,
    medicationName,
    dosage,
    condition,
    scheduledTime:  scheduledTime.trim(),
    fcmToken,
    createdAt:      new Date(),
    firedToday:     false,
    lastFiredAt:    null,
  });

  const action = isUpdate ? 'updated' : 'added';
  console.log(`[Queue] Reminder ${action}: ${queueId} — ${medicationName} at ${scheduledTime}`);

  return res.status(isUpdate ? 200 : 201).json({
    success:  true,
    action,
    queueId,
    message:  `Reminder ${action} for ${medicationName} at ${scheduledTime}`,
    queueSize: reminderQueue.size,
  });
});

// ── DELETE /cancel-medication ─────────────────────────────────────────────────
/**
 * Body: { userId, medicationId, scheduledTime }
 */
app.delete('/cancel-medication', (req, res) => {
  const { userId, medicationId, scheduledTime } = req.body || {};

  if (!userId || !medicationId || !scheduledTime) {
    return res.status(400).json({ error: 'Missing required fields: userId, medicationId, scheduledTime' });
  }

  const queueId = buildQueueId(userId, medicationId, scheduledTime);
  const existed = reminderQueue.delete(queueId);

  if (existed) {
    console.log(`[Queue] Reminder cancelled: ${queueId}`);
    return res.json({ success: true, message: 'Reminder cancelled', queueId });
  }

  return res.status(404).json({ error: 'Reminder not found', queueId });
});

// ── DELETE /cancel-all-medications/:userId ────────────────────────────────────
app.delete('/cancel-all-medications/:userId', (req, res) => {
  const { userId } = req.params;
  let count = 0;
  for (const [key] of reminderQueue) {
    if (key.startsWith(`${userId}_`)) {
      reminderQueue.delete(key);
      count++;
    }
  }
  console.log(`[Queue] Cancelled ${count} reminder(s) for user: ${userId}`);
  return res.json({ success: true, cancelled: count });
});

// ── GET /queue ────────────────────────────────────────────────────────────────
// Diagnostic — list all active reminders (omits FCM token for safety).
app.get('/queue', (_req, res) => {
  const entries = [...reminderQueue.values()].map(({ fcmToken: _t, ...safe }) => safe);
  return res.json({ count: entries.length, reminders: entries });
});

// ── GET /health ───────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  return res.json({
    status:    'ok',
    uptime:    process.uptime(),
    queueSize: reminderQueue.size,
    timestamp: new Date().toISOString(),
  });
});

// ── Catch-all 404 ─────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Not found' }));

// ── Global error handler ──────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('[Unhandled error]', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ─── Cron job — fire every minute ────────────────────────────────────────────
//
// Fires at :00 of every minute.
// For each reminder whose HH:MM matches NOW and hasn't fired today, sends FCM.
cron.schedule('* * * * *', async () => {
  const { h, m } = nowHHMM();
  const nowLabel  = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;

  // Collect due reminders (synchronously, don't mutate while iterating).
  const due = [];
  for (const reminder of reminderQueue.values()) {
    const t = parseHHMM(reminder.scheduledTime);
    if (!t) continue;
    if (t.h === h && t.m === m && !reminder.firedToday) {
      due.push(reminder);
    }
  }

  if (due.length === 0) {
    console.log(`[Cron] ${nowLabel} — no reminders due`);
    return;
  }

  console.log(`[Cron] ${nowLabel} — ${due.length} reminder(s) due`);

  // Fire all due reminders concurrently.
  await Promise.allSettled(
    due.map(async (reminder) => {
      try {
        const msgId = await sendFCM(reminder);
        reminder.firedToday = true;
        reminder.lastFiredAt = new Date();
        console.log(`[FCM ✅] Sent to ${reminder.userId} — ${reminder.medicationName} @ ${reminder.scheduledTime} | msgId: ${msgId}`);
      } catch (err) {
        console.error(`[FCM ❌] Failed for ${reminder.userId} — ${reminder.medicationName}: ${err.message}`);

        // If the token is invalid / unregistered, remove from queue to avoid
        // hammering FCM with bad tokens.
        if (
          err.code === 'messaging/invalid-registration-token' ||
          err.code === 'messaging/registration-token-not-registered'
        ) {
          reminderQueue.delete(reminder.id);
          console.warn(`[Queue] Removed stale token entry: ${reminder.id}`);
        }
      }
    })
  );
});

// ─── Reset firedToday flag at midnight ───────────────────────────────────────
cron.schedule('0 0 * * *', () => {
  let count = 0;
  for (const reminder of reminderQueue.values()) {
    if (reminder.firedToday) {
      reminder.firedToday = false;
      count++;
    }
  }
  console.log(`[Midnight reset] firedToday cleared for ${count} reminder(s)`);
});

// ─── Start server ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
  console.log(`
╔══════════════════════════════════════════════════════╗
║        CareLanka Reminder Backend — RUNNING          ║
╠══════════════════════════════════════════════════════╣
║  Port     : ${String(PORT).padEnd(38)}║
║  Env      : ${(process.env.NODE_ENV || 'development').padEnd(38)}║
║  Started  : ${new Date().toISOString().padEnd(38)}║
╚══════════════════════════════════════════════════════╝
  `);
});
