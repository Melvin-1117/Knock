-- RPC function to remove a mutual connection between two users
-- Deletes both directions (me → friend, friend → me) in one transaction.
-- Runs with SECURITY DEFINER so it can delete the friend's row even with RLS.

CREATE OR REPLACE FUNCTION remove_mutual_connection(p_friend_id uuid)
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
  IF p_friend_id = my_uid THEN
    RETURN;
  END IF;

  -- Remove my connection to friend
  DELETE FROM connections
  WHERE user_id = my_uid
    AND friend_id = p_friend_id;

  -- Remove friend's connection to me
  DELETE FROM connections
  WHERE user_id = p_friend_id
    AND friend_id = my_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION remove_mutual_connection(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_mutual_connection(uuid) TO anon;

