-- Store FCM device token per user for push notifications
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

COMMENT ON COLUMN profiles.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
