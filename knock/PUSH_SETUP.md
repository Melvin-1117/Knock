# Push notifications setup

The app stores your FCM token in Supabase and an Edge Function sends a push when someone sends you a knock. To get push working end-to-end:

## 1. Run the migration

Apply the new column so profiles can store the FCM token:

```bash
cd knock
supabase db push
# or apply the migration file manually in Supabase Dashboard → SQL: supabase/migrations/20250222000000_add_fcm_token_to_profiles.sql
```

## 2. Firebase service account (for sending from the server)

1. Open [Firebase Console](https://console.firebase.google.com/) → your project (**knock-2feab**) → Project settings (gear) → **Service accounts**.
2. Click **Generate new private key** and download the JSON file.
3. In **Supabase Dashboard** → **Project settings** → **Edge Functions** → **Secrets**, add:
   - Name: `FIREBASE_SERVICE_ACCOUNT_JSON`
   - Value: paste the **entire contents** of that JSON file (one line is fine).

## 3. Deploy the Edge Function

```bash
cd knock
supabase functions deploy send-knock-push
```

## 4. Database webhook (trigger on new knock)

1. In **Supabase Dashboard** → **Database** → **Webhooks** → **Create a new webhook**.
2. **Name:** e.g. `Send knock push`.
3. **Table:** `knocks`.
4. **Events:** tick **Insert**.
5. **Type:** **Supabase Edge Functions**.
6. **Function:** `send-knock-push`.
7. Save.

## 5. Test on device

1. Install the app on a physical Android device (FCM often doesn’t work on emulators).
2. Sign in and open the home screen so the app can save your FCM token to `profiles.fcm_token`.
3. From another account (or another device), send a knock to that user.
4. You should get a push notification: “Knock from [name]” with the message.

If you don’t get a notification, check:

- **Database webhook**: Supabase → **Database** → **Webhooks**. You must have a webhook on table `knocks`, event **Insert**, calling the `send-knock-push` function. Without this, FCM is never sent (in-app alerts still work via Realtime).
- **Supabase** → **Table Editor** → **profiles**: your row has a non-empty `fcm_token`.
- **Supabase** → **Edge Functions** → **send-knock-push** → **Logs** for errors (e.g. missing secret or FCM error).
- **Device**: Allow notifications for the app in system settings; ensure "Knocks" channel isn't muted.
