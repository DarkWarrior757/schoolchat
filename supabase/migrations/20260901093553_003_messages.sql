/*
# Create messages, pinned messages, and related tables

1. New Tables
- `messages`: chat messages in channels with content, author, edit tracking, soft delete
- `pinned_messages`: messages pinned by teachers/admins
2. Security
- RLS enabled
- Users can only see messages in channels they are members of
- Users can insert messages in channels they are members of (respecting channel type restrictions)
- Users can update/delete only their own messages
- Teachers/admins can delete any message in their class
- Only teachers/admins can pin messages
3. Indexes on channel_id and created_at for pagination
*/

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id uuid NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL DEFAULT '',
  reply_to uuid REFERENCES messages(id) ON DELETE SET NULL,
  is_edited boolean NOT NULL DEFAULT false,
  is_deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Pinned messages table
CREATE TABLE IF NOT EXISTS pinned_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  channel_id uuid NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  pinned_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(message_id)
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE pinned_messages ENABLE ROW LEVEL SECURITY;

-- Messages SELECT: user must be member of the channel's class
DROP POLICY IF EXISTS "messages_select_member" ON messages;
CREATE POLICY "messages_select_member" ON messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = messages.channel_id
      AND (is_class_member(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

-- Messages INSERT: user must be member of the channel's class
-- For announcement/read_only channels, only staff can post
DROP POLICY IF EXISTS "messages_insert_member" ON messages;
CREATE POLICY "messages_insert_member" ON messages
  FOR INSERT TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = messages.channel_id
      AND (
        is_class_staff(channels.class_id, auth.uid())
        OR (
          is_class_member(channels.class_id, auth.uid())
          AND channels.type NOT IN ('announcement', 'read_only')
        )
      )
    )
  );

-- Messages UPDATE: only author can edit their own message content
DROP POLICY IF EXISTS "messages_update_own" ON messages;
CREATE POLICY "messages_update_own" ON messages
  FOR UPDATE TO authenticated
  USING (author_id = auth.uid())
  WITH CHECK (author_id = auth.uid());

-- Messages DELETE: author or staff of the class
DROP POLICY IF EXISTS "messages_delete_own_or_staff" ON messages;
CREATE POLICY "messages_delete_own_or_staff" ON messages
  FOR DELETE TO authenticated
  USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = messages.channel_id
      AND (is_class_staff(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

-- Pinned messages SELECT: member of class
DROP POLICY IF EXISTS "pinned_select_member" ON pinned_messages;
CREATE POLICY "pinned_select_member" ON pinned_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = pinned_messages.channel_id
      AND (is_class_member(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

-- Pinned messages INSERT: staff only
DROP POLICY IF EXISTS "pinned_insert_staff" ON pinned_messages;
CREATE POLICY "pinned_insert_staff" ON pinned_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = pinned_messages.channel_id
      AND (is_class_staff(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

-- Pinned messages DELETE: staff only
DROP POLICY IF EXISTS "pinned_delete_staff" ON pinned_messages;
CREATE POLICY "pinned_delete_staff" ON pinned_messages
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = pinned_messages.channel_id
      AND (is_class_staff(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_channel_id ON messages (channel_id);
CREATE INDEX IF NOT EXISTS idx_messages_channel_created ON messages (channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_author_id ON messages (author_id);
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages (reply_to);
CREATE INDEX IF NOT EXISTS idx_pinned_messages_channel_id ON pinned_messages (channel_id);
