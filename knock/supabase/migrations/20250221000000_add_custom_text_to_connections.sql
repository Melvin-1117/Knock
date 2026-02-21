-- Add custom_text column to connections table for per-relationship custom knock messages
ALTER TABLE connections
ADD COLUMN IF NOT EXISTS custom_text TEXT;
