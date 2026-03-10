-- Add push_sent flag to knocks so the Edge Function can atomically
-- claim the right to send a push notification. This prevents duplicate
-- FCM messages when the Edge Function is invoked multiple times for the
-- same knock (e.g. webhook + direct client call).

ALTER TABLE knocks ADD COLUMN IF NOT EXISTS push_sent BOOLEAN NOT NULL DEFAULT false;
