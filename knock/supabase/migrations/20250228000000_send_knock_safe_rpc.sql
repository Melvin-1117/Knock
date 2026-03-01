-- RPC function to send a knock only if a mutual connection exists.
-- Prevents removed users from sending knocks to each other.
-- Runs with SECURITY DEFINER so it can check connections across RLS boundaries.

CREATE OR REPLACE FUNCTION send_knock_safe(p_receiver_id uuid, p_message text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  my_uid uuid;
  conn_exists boolean;
BEGIN
  my_uid := auth.uid();
  IF my_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_receiver_id = my_uid THEN
    RAISE EXCEPTION 'Cannot knock yourself';
  END IF;

  -- Check that a connection exists from sender to receiver
  SELECT EXISTS(
    SELECT 1 FROM connections
    WHERE user_id = my_uid
      AND friend_id = p_receiver_id
  ) INTO conn_exists;

  IF NOT conn_exists THEN
    RAISE EXCEPTION 'No connection exists with this user';
  END IF;

  -- Insert the knock
  INSERT INTO knocks (sender_id, receiver_id, message)
  VALUES (my_uid, p_receiver_id, p_message);
END;
$$;

GRANT EXECUTE ON FUNCTION send_knock_safe(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION send_knock_safe(uuid, text) TO anon;
