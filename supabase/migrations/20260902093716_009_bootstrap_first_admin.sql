/*
# Bootstrap first administrator

Problem: every new user gets role='student'. The set_user_role() function
requires the caller to already be admin. With no admin, nobody can promote
anyone — a chicken-and-egg lockout.

Solution: A SECURITY DEFINER function `claim_first_admin()` that:
1. Checks if ANY admin already exists in profiles
2. If no admin exists, promotes the calling user to admin
3. If an admin already exists, raises an error (refuses)

This is safe because:
- It only works when zero admins exist (one-shot bootstrap)
- Once the first admin claims the role, the function becomes a no-op
- Any authenticated user can call it, but only the first caller succeeds
*/

CREATE OR REPLACE FUNCTION public.claim_first_admin()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Refuse if an admin already exists
  IF EXISTS (SELECT 1 FROM profiles WHERE role = 'admin') THEN
    RAISE EXCEPTION 'An administrator already exists. Contact them to be promoted.';
  END IF;

  -- Caller must be authenticated
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to claim admin.';
  END IF;

  -- Promote the caller
  UPDATE profiles
  SET role = 'admin', updated_at = now()
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_first_admin TO authenticated;
