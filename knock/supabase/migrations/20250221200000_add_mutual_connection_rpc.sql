-- Add custom_text column for per-relationship custom knock messages
ALTER TABLE connections ADD COLUMN IF NOT EXISTS custom_text TEXT;

-- RPC function for mutual connection: inserts both directions in one transaction
-- Runs with SECURITY DEFINER to bypass RLS for the friend's row
CREATE OR REPLACE FUNCTION add_mutual_connection(friend_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  my_uid uuid;
BEGIN
  my_uid := auth.uid();
  IF my_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF friend_id = my_uid THEN
    RAISE EXCEPTION 'Cannot add yourself';
  END IF;

  -- Insert both rows (bypasses RLS via SECURITY DEFINER)
  INSERT INTO connections (user_id, friend_id, label)
  VALUES (my_uid, friend_id, 'Friend');

  INSERT INTO connections (user_id, friend_id, label)
  VALUES (friend_id, my_uid, 'Friend');
END;
$$;

-- Grant execute to authenticated and anon (for anonymous auth)
GRANT EXECUTE ON FUNCTION add_mutual_connection(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION add_mutual_connection(uuid) TO anon;
