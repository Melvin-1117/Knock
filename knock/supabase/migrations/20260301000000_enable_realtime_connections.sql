-- Enable Supabase Realtime on the connections table
-- Required for the onPostgresChanges() subscription to work
ALTER PUBLICATION supabase_realtime ADD TABLE connections;
