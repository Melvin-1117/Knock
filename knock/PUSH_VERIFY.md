# Verify Supabase settings for push notifications

Use this checklist in **Supabase Dashboard** to confirm everything is set for knock push notifications.

---

## 1. Database: `profiles` has `fcm_token` column

1. Open **Supabase Dashboard** → **Table Editor**.
2. Select the **`profiles`** table.
3. Check the columns: you should see **`fcm_token`** (type text, nullable).

**If missing:** Run the migration:
```bash
cd knock
supabase db push
```
Or in Dashboard → **SQL Editor**, run:
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
```

---

## 2. Edge Function secret: Firebase service account

1. Go to **Project settings** (gear icon in the left sidebar).
2. Open **Edge Functions**.
3. Click **Secrets** (or **Manage secrets**).
4. Ensure there is a secret named **`FIREBASE_SERVICE_ACCOUNT_JSON`**.
5. Its value must be the **full JSON** of your Firebase service account key (from Firebase Console → Project settings → Service accounts → Generate new private key).

**If missing:** Add the secret with that exact name and paste the entire JSON content.

---

## 3. Edge Function is deployed

1. Go to **Edge Functions** in the left sidebar.
2. You should see **`send-knock-push`** in the list.
3. It should show a status like “Deployed” and a recent deployment time.

**If missing or outdated:** From your project root:
```bash
cd knock
supabase functions deploy send-knock-push
```

---

## 4. Database webhook (triggers FCM on new knock)

1. Go to **Database** → **Webhooks**.
2. You should have at least one webhook. Open it and verify:
   - **Name:** e.g. `Send knock push` (any name is fine).
   - **Table:** **`knocks`**.
   - **Events:** **Insert** is enabled (other events can be off).
   - **Type:** **Supabase Edge Functions**.
   - **Function:** **`send-knock-push`**.

**If missing:** Click **Create a new webhook** and set the fields above, then save.

This webhook is what sends the push when a row is inserted into `knocks`. Without it, only in-app (Realtime) notifications work; no system push.

---

## 5. App is saving FCM token to `profiles`

1. Install and open the app on a **physical device** (same project as your Supabase).
2. Sign in and land on the **Home** screen (so the app can request notification permission and get the token).
3. In **Supabase Dashboard** → **Table Editor** → **`profiles`**, find the row for that user (match by `id` or email/username).
4. Check the **`fcm_token`** column: it should be a long non-empty string (FCM device token). Empty or null means the app didn’t save the token (permission denied, emulator, or web).

**If empty:** Ensure notifications are allowed for the app in device settings, and that you’re on a real device, not an emulator.

---

## 6. Edge Function logs (when testing)

1. Go to **Edge Functions** → **send-knock-push**.
2. Open **Logs** (or **Invocations**).
3. Send a knock to a user who has the app installed and a non-empty `fcm_token`.
4. You should see a log entry for that request. Check:
   - **Status 200** and a body like `{"ok":true,"sent":true}` → FCM was sent.
   - **Status 200** and `"skipped":"receiver has no fcm_token"` → receiver’s `profiles.fcm_token` is null/empty.
   - **Status 500** or error message → check the message (e.g. missing `FIREBASE_SERVICE_ACCOUNT_JSON`, or FCM/network error).

---

## Quick checklist

| Step | Where in Supabase | What to verify |
|------|-------------------|----------------|
| 1 | Table Editor → `profiles` | Column `fcm_token` exists |
| 2 | Project settings → Edge Functions → Secrets | `FIREBASE_SERVICE_ACCOUNT_JSON` is set |
| 3 | Edge Functions | `send-knock-push` is deployed |
| 4 | Database → Webhooks | Webhook on table `knocks`, event **Insert**, function `send-knock-push` |
| 5 | Table Editor → `profiles` | Test user’s row has non-empty `fcm_token` |
| 6 | Edge Functions → send-knock-push → Logs | After sending a knock, log shows 200 and `sent: true` or a clear error |

Once all of these are correct, knock inserts should trigger the function and the receiver should get a push notification at the top of the screen (if the device allows it).
