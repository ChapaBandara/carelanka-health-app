# CareLanka Reminder Backend

Express + Firebase Admin SDK backend that queues medication reminders and delivers them via FCM push notifications.

---

## Endpoints

| Method   | Path                                  | Description                        |
|----------|---------------------------------------|------------------------------------|
| `POST`   | `/schedule-medication`                | Add or update a reminder           |
| `DELETE` | `/cancel-medication`                  | Cancel one reminder                |
| `DELETE` | `/cancel-all-medications/:userId`     | Cancel all reminders for a user    |
| `GET`    | `/queue`                              | Inspect the in-memory queue        |
| `GET`    | `/health`                             | Health check + uptime              |

### POST `/schedule-medication`

```json
{
  "userId":         "abc123",
  "medicationId":   "med_456",
  "medicationName": "Metformin",
  "dosage":         "500mg",
  "condition":      "Diabetes",
  "scheduledTime":  "08:00",
  "fcmToken":       "eX...token"
}
```

---

## Local Development

```bash
cd backend
npm install

# Set the env var (paste your full serviceAccountKey.json content):
export FIREBASE_SERVICE_ACCOUNT_JSON='{ "type": "service_account", ... }'

npm run dev   # uses --watch for auto-reload
```

---

## Deploy to Render.com (Free Tier)

1. Push this `backend/` folder (or the whole repo) to GitHub.
2. Create a new **Web Service** on [render.com](https://render.com).
3. Settings:
   - **Root directory**: `backend`
   - **Build command**: `npm install`
   - **Start command**: `node server.js`
   - **Node version**: `20`
4. Add environment variable in the Render dashboard:
   - Key: `FIREBASE_SERVICE_ACCOUNT_JSON`
   - Value: *(paste the entire contents of your `serviceAccountKey.json`)*
5. Deploy — Render assigns a public URL automatically.

> ⚠️ Render free tier **spins down after 15 minutes of inactivity**. Use a free uptime monitor (e.g. UptimeRobot) to ping `/health` every 5 minutes.

---

## How it Works

- Every **incoming POST** upserts a reminder into an in-memory `Map` keyed by `userId_medicationId_HH:MM`.
- A **`node-cron`** job fires every minute, compares `HH:MM` of all queued reminders against the current time, and sends FCM to any that are due and haven't fired yet today.
- A **midnight cron** resets the `firedToday` flag so each reminder fires again the next day.
- Invalid/expired FCM tokens are automatically removed from the queue.

---

## Getting Your Service Account Key

1. Firebase Console → Project Settings → Service Accounts
2. Click **"Generate new private key"** → Download JSON
3. Paste the full file contents as the `FIREBASE_SERVICE_ACCOUNT_JSON` env var
