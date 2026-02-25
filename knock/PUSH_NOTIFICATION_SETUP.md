# Complete Guide: Get Push Notifications Working

Follow these steps in order to enable push notifications for your Knock app.

---

## ✅ Step 1: Firebase Project Setup

### 1.1 Create/Verify Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create one named **knock-2feab**)
3. Note your **Project ID** (you'll need it later)

### 1.2 Add Android App to Firebase
1. In Firebase Console → **Project Overview** → **Add app** → **Android**
2. **Package name**: Check `android/app/build.gradle` → `applicationId` (e.g., `com.example.knock`)
3. **App nickname**: "Knock Android"
4. Click **Register app**

### 1.3 Download `google-services.json`
1. Download the `google-services.json` file
2. Place it in: `knock/android/app/google-services.json`
   - **Important**: Replace any existing file

### 1.4 Get Firebase Service Account Key
1. Firebase Console → **Project settings** (gear icon) → **Service accounts**
2. Click **Generate new private key**
3. Download the JSON file (keep it safe - contains sensitive credentials)
4. **Copy the entire contents** of this JSON file (you'll paste it into Supabase in Step 3)

---

## ✅ Step 2: Android Project Configuration

### 2.1 Verify `google-services.json` is in place
```
knock/android/app/google-services.json  ← Must exist
```

### 2.2 Check `android/app/build.gradle`
Open `knock/android/app/build.gradle` and ensure:

```gradle
dependencies {
    // ... other dependencies
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

At the **bottom** of the file:
```gradle
apply plugin: 'com.google.gms.google-services'
```

### 2.3 Check `android/build.gradle`
Open `knock/android/build.gradle` and ensure:

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
    // ... other classpaths
}
```

---

## ✅ Step 3: Supabase Configuration

### 3.1 Run Database Migration
```bash
cd c:\Users\anton\Knock_app\knock
supabase db push
```

Or manually in **Supabase Dashboard** → **SQL Editor**:
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
COMMENT ON COLUMN profiles.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
```

### 3.2 Add Firebase Service Account Secret
1. **Supabase Dashboard** → **Project settings** (gear) → **Edge Functions** → **Secrets**
2. Click **Add new secret**
3. **Name**: `FIREBASE_SERVICE_ACCOUNT_JSON`
4. **Value**: Paste the **entire JSON** from Step 1.4 (the service account key)
5. Click **Save**

### 3.3 Deploy Edge Function
```bash
cd c:\Users\anton\Knock_app\knock
supabase functions deploy send-knock-push
```

Verify in **Supabase Dashboard** → **Edge Functions** → `send-knock-push` shows as **Deployed**.

### 3.4 Create Database Webhook
1. **Supabase Dashboard** → **Database** → **Webhooks**
2. Click **Create a new webhook**
3. Fill in:
   - **Name**: `Send knock push`
   - **Table**: `knocks`
   - **Events**: ✅ **Insert** (uncheck others)
   - **Type**: **Supabase Edge Functions**
   - **Function**: `send-knock-push`
4. Click **Save**

**⚠️ Critical**: Without this webhook, no push notifications will be sent!

---

## ✅ Step 4: Install & Test on Physical Android Device

### 4.1 Connect Physical Device
1. Enable **Developer options** and **USB debugging** on your Android phone
2. Connect via USB (or use wireless debugging)
3. Verify device is detected:
   ```bash
   flutter devices
   ```
   You should see your Android device listed

### 4.2 Run App on Device
```bash
cd c:\Users\anton\Knock_app\knock
flutter run -d <your-device-id>
```

Or in **Android Studio**: Select your **Android device** from the device dropdown → Click **Run**

### 4.3 Grant Notification Permission
1. When the app opens, it should request notification permission
2. Click **Allow** (or go to device **Settings** → **Apps** → **Knock** → **Notifications** → Enable)

### 4.4 Verify Token Saved
1. **Supabase Dashboard** → **Table Editor** → **profiles**
2. Find your user row (by `id` or `username`)
3. Check **`fcm_token`** column: Should be a **long string** (not null/empty)

If it's still null:
- Check device console logs for `FCM:` messages
- Ensure you're on a **physical device** (not emulator)
- Ensure notifications are **allowed** in device settings

---

## ✅ Step 5: Test Push Notification

### Option A: Manual Test via Supabase SQL
1. **Supabase Dashboard** → **SQL Editor**
2. Run:
   ```sql
   -- Replace YOUR_USER_ID with your actual user ID from profiles table
   INSERT INTO knocks (sender_id, receiver_id, message)
   VALUES ('any-user-id', 'YOUR_USER_ID', 'Test push notification');
   ```
3. **Minimize or lock your phone** (app should be in background)
4. You should receive a push notification: **"Knock from [name]"** with the message

### Option B: Test from Another Device/Account
1. Install app on **Device 2** (or use emulator)
2. Log in as **User B**
3. Send a knock to **User A** (your account on Device 1)
4. **Device 1** should receive push notification

---

## ✅ Step 6: Verify Everything Works

### Check Edge Function Logs
1. **Supabase Dashboard** → **Edge Functions** → **send-knock-push** → **Logs**
2. After sending a knock, you should see:
   - **Status**: `200`
   - **Response**: `{"ok":true,"sent":true}`

If you see errors:
- **500 error**: Check `FIREBASE_SERVICE_ACCOUNT_JSON` secret is set correctly
- **"receiver has no fcm_token"**: Receiver's token wasn't saved (check Step 4.4)

### Check Device Settings
1. **Settings** → **Apps** → **Knock** → **Notifications**
2. Ensure **"Knocks"** channel is enabled and not muted
3. Ensure **"Show notifications"** is ON

---

## 🔍 Troubleshooting

### Token is null in Supabase
- ✅ Running on **physical device**? (not emulator)
- ✅ Notifications **allowed** in device settings?
- ✅ App reached **HomeScreen** after login? (token saves there)
- ✅ Check console logs for `FCM:` messages

### No push notification received
- ✅ **Webhook** exists on `knocks` table, event **Insert**?
- ✅ **Edge function** is deployed?
- ✅ **FCM token** is saved in `profiles.fcm_token`?
- ✅ **Edge function logs** show `200` and `sent: true`?
- ✅ App is in **background** or **killed**? (foreground shows in-app snackbar)
- ✅ Device **notifications** are enabled for Knock app?

### Edge function errors
- ✅ `FIREBASE_SERVICE_ACCOUNT_JSON` secret exists and is valid JSON?
- ✅ Firebase **project ID** matches the service account JSON?
- ✅ Check **Edge Functions** → **Logs** for specific error messages

---

## 📋 Quick Checklist

- [ ] Firebase project created
- [ ] Android app added to Firebase
- [ ] `google-services.json` downloaded and placed in `android/app/`
- [ ] Firebase service account key downloaded
- [ ] Database migration run (`fcm_token` column exists)
- [ ] Supabase secret `FIREBASE_SERVICE_ACCOUNT_JSON` added
- [ ] Edge function `send-knock-push` deployed
- [ ] Database webhook created (table: `knocks`, event: Insert)
- [ ] App installed on **physical Android device**
- [ ] Notification permission granted
- [ ] FCM token saved in `profiles.fcm_token` (check Supabase)
- [ ] Tested by inserting knock row or sending from another account
- [ ] Push notification received ✅

---

Once all steps are complete, push notifications should work! If you still have issues, check the **Edge Function logs** in Supabase for specific error messages.
