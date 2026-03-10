-- Update send_knock_safe to return the new knock's UUID.
-- The Flutter client captures this ID and passes it to the Edge Function
-- so the Edge Function can atomically mark push_sent = true and skip
-- any duplicate invocations.

CREATE OR REPLACE FUNCTION send_knock_safe(p_receiver_id uuid, p_message text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  my_uid uuid;
  conn_exists boolean;
  new_knock_id uuid;
BEGIN
  my_uid := auth.uid();
  IF my_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_receiver_id = my_uid THEN
    RAISE EXCEPTION 'Cannot knock yourself';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM connections
    WHERE user_id = my_uid
      AND friend_id = p_receiver_id
  ) INTO conn_exists;

  IF NOT conn_exists THEN
    RAISE EXCEPTION 'No connection exists with this user';
  END IF;

  INSERT INTO knocks (sender_id, receiver_id, message)
  VALUES (my_uid, p_receiver_id, p_message)
  RETURNING id INTO new_knock_id;

  RETURN new_knock_id;
END;
$$;

GRANT EXECUTE ON FUNCTION send_knock_safe(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION send_knock_safe(uuid, text) TO anon;
