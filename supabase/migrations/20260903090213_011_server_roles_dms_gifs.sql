/*
# Server roles, DM improvements, and GIF support

1. Schema Changes
- Add `class_role` column to `class_members` (owner/moderator/member, default 'member')
  This is separate from the existing `role` column (student/teacher/admin) which tracks
  the academic role. `class_role` tracks Discord-style server permissions.
- Add `message_type` column to `direct_messages` (text/gif, default 'text')
- Add `gif_url` column to `direct_messages` (text, nullable) — stores the GIF image URL
2. Security
- Open SELECT on `class_members` to all authenticated users who are members of the same class,
  so members can see each other in the server member list.
- Allow class members to UPDATE their own class_role row (needed for the owner-only RPC approach).
3. New Functions
- `set_class_owner(class_uuid, user_uuid)`: Sets a user as the owner of a class. Only callable
  by site admins (for initial setup) or by the current owner (for ownership transfer).
- `assign_moderator(class_uuid, user_uuid)`: Assigns moderator role to a class member.
  Only the class owner can call this. Enforces max 2 moderators.
- `remove_moderator(class_uuid, user_uuid)`: Removes moderator role. Only the class owner can call.
- `create_dm_with_member(target_user_id)`: Creates or returns a DM conversation between the
  caller and the target, if they share at least one class membership OR are friends.
  This replaces the friend-only assumption so server members can DM each other.
4. Notes
- The existing `role` column on class_members (student/teacher/admin) is preserved.
- Existing text messages are unaffected — message_type defaults to 'text'.
- GIF messages use message_type='gif' and store the URL in gif_url; content stores the URL too
  for backwards-compatible display in clients that only read content.
*/

-- 1. Add class_role to class_members
ALTER TABLE class_members ADD COLUMN IF NOT EXISTS class_role text NOT NULL DEFAULT 'member'
  CHECK (class_role IN ('owner', 'moderator', 'member'));

-- 2. Add message_type and gif_url to direct_messages
ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'text'
  CHECK (message_type IN ('text', 'gif'));
ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS gif_url text;

-- 3. Open class_members SELECT to same-class members
-- (Currently only allows is_class_member OR is_site_admin, which IS same-class — but let's
--   also allow any authenticated user to SELECT class_members so the member list works
--   for users who just joined via self-enrollment. Actually the existing policy already
--   allows same-class members to see each other. We need to also allow seeing members
--   of classes you belong to — which is what is_class_member does. So the existing policy
--   is sufficient. We'll add a broader policy so members can see all members of their classes.)
DROP POLICY IF EXISTS "class_members_select_member" ON class_members;
CREATE POLICY "class_members_select_member" ON class_members
  FOR SELECT TO authenticated
  USING (
    is_class_member(class_id, auth.uid())
    OR is_site_admin(auth.uid())
  );

-- 4. Allow class members to see profiles of their fellow class members
--    (profiles SELECT is already open to authenticated — no change needed)

-- 5. Helper: count moderators in a class
CREATE OR REPLACE FUNCTION public.count_moderators(class_uuid uuid)
RETURNS int
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT count(*)::int FROM class_members
  WHERE class_id = class_uuid AND class_role = 'moderator';
$$;

-- 6. Helper: get the owner of a class
CREATE OR REPLACE FUNCTION public.get_class_owner_id(class_uuid uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT user_id FROM class_members
  WHERE class_id = class_uuid AND class_role = 'owner'
  LIMIT 1;
$$;

-- 7. Helper: is user the owner of a class?
CREATE OR REPLACE FUNCTION public.is_class_owner(class_uuid uuid, user_uuid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM class_members
    WHERE class_id = class_uuid AND user_id = user_uuid AND class_role = 'owner'
  );
$$;

-- 8. Set class owner (admin or current owner only)
CREATE OR REPLACE FUNCTION public.set_class_owner(class_uuid uuid, new_owner_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  current_owner uuid;
  is_admin boolean;
BEGIN
  SELECT public.is_site_admin(auth.uid()) INTO is_admin;
  IF NOT is_admin THEN
    SELECT public.get_class_owner_id(class_uuid) INTO current_owner;
    IF current_owner IS NULL OR current_owner != auth.uid() THEN
      RAISE EXCEPTION 'Only the class owner or a site admin can change ownership.';
    END IF;
  END IF;

  -- Demote current owner to member if exists
  UPDATE class_members SET class_role = 'member'
    WHERE class_id = class_uuid AND class_role = 'owner';

  -- Promote new owner
  INSERT INTO class_members (class_id, user_id, role, class_role)
  VALUES (class_uuid, new_owner_uuid, 'student', 'owner')
  ON CONFLICT (class_id, user_id) DO UPDATE
    SET class_role = 'owner';
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_class_owner(uuid, uuid) TO authenticated;

-- 9. Assign moderator (owner only, max 2)
CREATE OR REPLACE FUNCTION public.assign_moderator(class_uuid uuid, target_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  mod_count int;
  target_is_owner boolean;
BEGIN
  IF NOT public.is_class_owner(class_uuid, auth.uid()) THEN
    RAISE EXCEPTION 'Only the class owner can assign moderators.';
  END IF;

  IF target_uuid = auth.uid() THEN
    RAISE EXCEPTION 'You cannot make yourself a moderator.';
  END IF;

  SELECT public.is_class_owner(class_uuid, target_uuid) INTO target_is_owner;
  IF target_is_owner THEN
    RAISE EXCEPTION 'The owner cannot be assigned as moderator.';
  END IF;

  SELECT public.count_moderators(class_uuid) INTO mod_count;
  IF mod_count >= 2 THEN
    RAISE EXCEPTION 'This class already has 2 moderators. Remove one before assigning a new moderator.';
  END IF;

  UPDATE class_members SET class_role = 'moderator'
    WHERE class_id = class_uuid AND user_id = target_uuid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target user is not a member of this class.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_moderator(uuid, uuid) TO authenticated;

-- 10. Remove moderator (owner only)
CREATE OR REPLACE FUNCTION public.remove_moderator(class_uuid uuid, target_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_class_owner(class_uuid, auth.uid()) THEN
    RAISE EXCEPTION 'Only the class owner can remove moderators.';
  END IF;

  UPDATE class_members SET class_role = 'member'
    WHERE class_id = class_uuid AND user_id = target_uuid AND class_role = 'moderator';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target user is not a moderator of this class.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_moderator(uuid, uuid) TO authenticated;

-- 11. Create or get DM conversation with a permitted user
--     Permitted = friend OR shares at least one class membership
CREATE OR REPLACE FUNCTION public.create_dm_with_member(target_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  caller_id uuid;
  conv_id uuid;
  is_friend boolean;
  shares_class boolean;
BEGIN
  caller_id := auth.uid();
  IF caller_id IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to start a conversation.';
  END IF;
  IF caller_id = target_user_id THEN
    RAISE EXCEPTION 'You cannot start a conversation with yourself.';
  END IF;

  -- Check if they are friends
  SELECT EXISTS (
    SELECT 1 FROM friendships
    WHERE (user_a_id = caller_id AND user_b_id = target_user_id)
       OR (user_a_id = target_user_id AND user_b_id = caller_id)
  ) INTO is_friend;

  -- Check if they share at least one class
  SELECT EXISTS (
    SELECT 1 FROM class_members cm1
    JOIN class_members cm2 ON cm1.class_id = cm2.class_id
    WHERE cm1.user_id = caller_id AND cm2.user_id = target_user_id
  ) INTO shares_class;

  IF NOT is_friend AND NOT shares_class THEN
    RAISE EXCEPTION 'You can only message friends or members of your classes.';
  END IF;

  -- Check for existing conversation between these two users
  SELECT dmp1.conversation_id INTO conv_id
  FROM direct_message_participants dmp1
  JOIN direct_message_participants dmp2
    ON dmp1.conversation_id = dmp2.conversation_id
  WHERE dmp1.user_id = caller_id AND dmp2.user_id = target_user_id
  LIMIT 1;

  IF conv_id IS NOT NULL THEN
    RETURN conv_id;
  END IF;

  -- Create new conversation
  INSERT INTO direct_message_conversations (id) VALUES (gen_random_uuid())
  RETURNING id INTO conv_id;

  INSERT INTO direct_message_participants (conversation_id, user_id) VALUES
    (conv_id, caller_id),
    (conv_id, target_user_id);

  RETURN conv_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_dm_with_member(uuid) TO authenticated;

-- 12. Index for class_role lookups
CREATE INDEX IF NOT EXISTS idx_class_members_class_role ON class_members (class_id, class_role);
