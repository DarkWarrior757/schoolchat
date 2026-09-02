/*
# Allow self-enrollment into classes during signup

1. Open SELECT on classes and sections to all authenticated users
   so they can browse available classes/sections during the class selection step.
2. Create a SECURITY DEFINER function `enroll_self(class_uuid, section_uuid)`
   that lets any authenticated user add themselves to a class (and optionally a section).
   This bypasses the staff-only INSERT policy on class_members.
3. Add a policy allowing users to insert their own class_members row directly
   (belt-and-suspenders alongside the RPC).
*/

-- Open class listing to all authenticated users (needed for signup picker)
DROP POLICY IF EXISTS "classes_select_member" ON classes;
CREATE POLICY "classes_select_all_authenticated" ON classes
  FOR SELECT TO authenticated USING (true);

-- Open sections listing to all authenticated users
DROP POLICY IF EXISTS "sections_select_member" ON sections;
CREATE POLICY "sections_select_all_authenticated" ON sections
  FOR SELECT TO authenticated USING (true);

-- Allow users to self-enroll
DROP POLICY IF EXISTS "class_members_insert_staff" ON class_members;
CREATE POLICY "class_members_insert_self_or_staff" ON class_members
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR is_class_staff(class_id, auth.uid())
    OR is_site_admin(auth.uid())
  );

-- SECURITY DEFINER function for self-enrollment (used by the client RPC call)
CREATE OR REPLACE FUNCTION public.enroll_self(class_uuid uuid, section_uuid uuid DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to enroll.';
  END IF;

  -- Validate the class exists
  IF NOT EXISTS (SELECT 1 FROM classes WHERE id = class_uuid) THEN
    RAISE EXCEPTION 'Selected class does not exist.';
  END IF;

  -- Validate the section belongs to the class (if provided)
  IF section_uuid IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM sections WHERE id = section_uuid AND class_id = class_uuid) THEN
      RAISE EXCEPTION 'Selected section does not belong to this class.';
    END IF;
  END IF;

  -- Insert membership (idempotent — if already a member, do nothing)
  INSERT INTO class_members (class_id, user_id, role, section_id)
  VALUES (class_uuid, auth.uid(), 'student', section_uuid)
  ON CONFLICT (class_id, user_id) DO UPDATE
    SET section_id = COALESCE(section_uuid, class_members.section_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.enroll_self(uuid, uuid) TO authenticated;
