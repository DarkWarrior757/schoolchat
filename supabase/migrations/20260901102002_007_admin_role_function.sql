/*
# Add admin role-change SECURITY DEFINER function

1. Functions
- `set_user_role(target_uuid, new_role)`: allows a site admin to change another user's role. SECURITY DEFINER so it runs with elevated privileges. Checks that the caller is an admin. Prevents self-demotion to avoid lockout.
2. Security
- Only callable by authenticated users who are site admins (role = 'admin' in profiles).
- Cannot change own role (prevents accidental self-lockout).
- Validates the new role is one of the allowed values.
*/

CREATE OR REPLACE FUNCTION public.set_user_role(target_uuid uuid, new_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Caller must be an admin
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only administrators can change roles';
  END IF;

  -- Cannot change own role
  IF auth.uid() = target_uuid THEN
    RAISE EXCEPTION 'You cannot change your own role';
  END IF;

  -- Validate role
  IF new_role NOT IN ('student', 'teacher', 'moderator', 'admin') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;

  UPDATE profiles SET role = new_role, updated_at = now() WHERE id = target_uuid;
END;
$$;

-- Grant execute to authenticated
GRANT EXECUTE ON FUNCTION public.set_user_role TO authenticated;
