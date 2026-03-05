-- RPC function to retrieve the auth email for a given knock_code.
-- Used by the login feature so users can sign in with just their Knock ID.
-- Runs as SECURITY DEFINER to access auth.users (not accessible to clients).

CREATE OR REPLACE FUNCTION get_auth_email_by_knock_code(p_knock_code text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_email text;
BEGIN
  SELECT id INTO v_user_id FROM profiles WHERE knock_code = p_knock_code;
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
  RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION get_auth_email_by_knock_code(text) TO anon;
GRANT EXECUTE ON FUNCTION get_auth_email_by_knock_code(text) TO authenticated;
