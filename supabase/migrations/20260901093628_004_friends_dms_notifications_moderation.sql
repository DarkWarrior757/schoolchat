/*
# Create friends, DMs, notifications, reports, moderation, blocks, mutes, terms, and audit tables

1. New Tables
- `friend_requests`: pending/accepted/declined/cancelled requests between users
- `friendships`: accepted friendships (bidirectional, stored as user_a < user_b by id ordering)
- `user_blocks`: user blocks another user
- `user_mutes`: user mutes another user
- `direct_message_conversations`: DM conversation containers
- `direct_message_participants`: participants in a DM conversation
- `direct_messages`: messages in DM conversations
- `notifications`: in-app notifications (friend requests, mentions, DMs, etc.)
- `reports`: user-submitted reports for messages or users
- `moderation_actions`: actions taken by moderators/admins
- `terms_versions`: terms & conditions versions
- `terms_acceptances`: user acceptance of terms versions
- `audit_logs`: audit trail for admin actions
- `attachments`: file attachments for messages (metadata only)
2. Security
- RLS enabled on all tables
- Users can only see their own friend requests, friendships, blocks, mutes
- DM participants can only see conversations they are part of
- Notifications are owner-scoped
- Reports: reporter can see their own; admins can see all
- Moderation actions: admins only
- Terms: public read, acceptances are owner-scoped
- Audit logs: admins only
*/

-- Friend requests
CREATE TABLE IF NOT EXISTS friend_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(sender_id, receiver_id),
  CHECK (sender_id != receiver_id)
);

-- Friendships (accepted)
CREATE TABLE IF NOT EXISTS friendships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_a_id, user_b_id),
  CHECK (user_a_id != user_b_id)
);

-- User blocks
CREATE TABLE IF NOT EXISTS user_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

-- User mutes
CREATE TABLE IF NOT EXISTS user_mutes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  muter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  muted_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(muter_id, muted_id),
  CHECK (muter_id != muted_id)
);

-- DM conversations
CREATE TABLE IF NOT EXISTS direct_message_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- DM participants
CREATE TABLE IF NOT EXISTS direct_message_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES direct_message_conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Direct messages
CREATE TABLE IF NOT EXISTS direct_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES direct_message_conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL DEFAULT '',
  is_edited boolean NOT NULL DEFAULT false,
  is_deleted boolean NOT NULL DEFAULT false,
  reply_to uuid REFERENCES direct_messages(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('friend_request', 'friend_accept', 'dm', 'mention', 'reply', 'report_update', 'system')),
  title text NOT NULL DEFAULT '',
  body text DEFAULT '',
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resource_id uuid,
  resource_type text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Reports
CREATE TABLE IF NOT EXISTS reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  message_id uuid REFERENCES messages(id) ON DELETE SET NULL,
  reason text NOT NULL CHECK (reason IN ('bullying', 'harassment', 'spam', 'inappropriate', 'impersonation', 'other')),
  description text DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
  resolved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resolution_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Moderation actions
CREATE TABLE IF NOT EXISTS moderation_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  moderator_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('warning', 'mute', 'kick', 'ban', 'unmute', 'unban')),
  reason text DEFAULT '',
  report_id uuid REFERENCES reports(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Terms versions
CREATE TABLE IF NOT EXISTS terms_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version text NOT NULL UNIQUE,
  title text NOT NULL DEFAULT 'Terms & Conditions',
  content text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Terms acceptances
CREATE TABLE IF NOT EXISTS terms_acceptances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  terms_version_id uuid NOT NULL REFERENCES terms_versions(id) ON DELETE CASCADE,
  accepted_at timestamptz DEFAULT now(),
  UNIQUE(user_id, terms_version_id)
);

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action text NOT NULL DEFAULT '',
  target_type text,
  target_id uuid,
  details text DEFAULT '',
  created_at timestamptz DEFAULT now()
);

-- Attachments (metadata for message files)
CREATE TABLE IF NOT EXISTS attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  dm_message_id uuid REFERENCES direct_messages(id) ON DELETE CASCADE,
  uploader_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  file_name text NOT NULL DEFAULT '',
  file_type text NOT NULL DEFAULT '',
  file_size bigint NOT NULL DEFAULT 0,
  storage_path text NOT NULL DEFAULT '',
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on all
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_message_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_message_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE moderation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE terms_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE terms_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;

-- Friend requests policies
DROP POLICY IF EXISTS "friend_requests_select_involved" ON friend_requests;
CREATE POLICY "friend_requests_select_involved" ON friend_requests
  FOR SELECT TO authenticated
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

DROP POLICY IF EXISTS "friend_requests_insert_sender" ON friend_requests;
CREATE POLICY "friend_requests_insert_sender" ON friend_requests
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "friend_requests_update_involved" ON friend_requests;
CREATE POLICY "friend_requests_update_involved" ON friend_requests
  FOR UPDATE TO authenticated
  USING (sender_id = auth.uid() OR receiver_id = auth.uid())
  WITH CHECK (sender_id = auth.uid() OR receiver_id = auth.uid());

DROP POLICY IF EXISTS "friend_requests_delete_sender" ON friend_requests;
CREATE POLICY "friend_requests_delete_sender" ON friend_requests
  FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- Friendships policies
DROP POLICY IF EXISTS "friendships_select_member" ON friendships;
CREATE POLICY "friendships_select_member" ON friendships
  FOR SELECT TO authenticated
  USING (user_a_id = auth.uid() OR user_b_id = auth.uid());

DROP POLICY IF EXISTS "friendships_insert_member" ON friendships;
CREATE POLICY "friendships_insert_member" ON friendships
  FOR INSERT TO authenticated
  WITH CHECK (user_a_id = auth.uid() OR user_b_id = auth.uid());

DROP POLICY IF EXISTS "friendships_delete_member" ON friendships;
CREATE POLICY "friendships_delete_member" ON friendships
  FOR DELETE TO authenticated
  USING (user_a_id = auth.uid() OR user_b_id = auth.uid());

-- User blocks policies
DROP POLICY IF EXISTS "user_blocks_select_blocker" ON user_blocks;
CREATE POLICY "user_blocks_select_blocker" ON user_blocks
  FOR SELECT TO authenticated
  USING (blocker_id = auth.uid());

DROP POLICY IF EXISTS "user_blocks_insert_blocker" ON user_blocks;
CREATE POLICY "user_blocks_insert_blocker" ON user_blocks
  FOR INSERT TO authenticated
  WITH CHECK (blocker_id = auth.uid());

DROP POLICY IF EXISTS "user_blocks_delete_blocker" ON user_blocks;
CREATE POLICY "user_blocks_delete_blocker" ON user_blocks
  FOR DELETE TO authenticated
  USING (blocker_id = auth.uid());

-- User mutes policies
DROP POLICY IF EXISTS "user_mutes_select_muter" ON user_mutes;
CREATE POLICY "user_mutes_select_muter" ON user_mutes
  FOR SELECT TO authenticated
  USING (muter_id = auth.uid());

DROP POLICY IF EXISTS "user_mutes_insert_muter" ON user_mutes;
CREATE POLICY "user_mutes_insert_muter" ON user_mutes
  FOR INSERT TO authenticated
  WITH CHECK (muter_id = auth.uid());

DROP POLICY IF EXISTS "user_mutes_delete_muter" ON user_mutes;
CREATE POLICY "user_mutes_delete_muter" ON user_mutes
  FOR DELETE TO authenticated
  USING (muter_id = auth.uid());

-- DM conversation helper: is user a participant?
CREATE OR REPLACE FUNCTION public.is_dm_participant(conv_uuid uuid, user_uuid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM direct_message_participants
    WHERE conversation_id = conv_uuid AND user_id = user_uuid
  );
$$;

-- DM conversations policies
DROP POLICY IF EXISTS "dm_conversations_select_participant" ON direct_message_conversations;
CREATE POLICY "dm_conversations_select_participant" ON direct_message_conversations
  FOR SELECT TO authenticated
  USING (is_dm_participant(id, auth.uid()));

DROP POLICY IF EXISTS "dm_conversations_insert_participant" ON direct_message_conversations;
CREATE POLICY "dm_conversations_insert_participant" ON direct_message_conversations
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "dm_conversations_update_participant" ON direct_message_conversations;
CREATE POLICY "dm_conversations_update_participant" ON direct_message_conversations
  FOR UPDATE TO authenticated
  USING (is_dm_participant(id, auth.uid()))
  WITH CHECK (is_dm_participant(id, auth.uid()));

-- DM participants policies
DROP POLICY IF EXISTS "dm_participants_select_participant" ON direct_message_participants;
CREATE POLICY "dm_participants_select_participant" ON direct_message_participants
  FOR SELECT TO authenticated
  USING (is_dm_participant(conversation_id, auth.uid()));

DROP POLICY IF EXISTS "dm_participants_insert_participant" ON direct_message_participants;
CREATE POLICY "dm_participants_insert_participant" ON direct_message_participants
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "dm_participants_delete_participant" ON direct_message_participants;
CREATE POLICY "dm_participants_delete_participant" ON direct_message_participants
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Direct messages policies
DROP POLICY IF EXISTS "direct_messages_select_participant" ON direct_messages;
CREATE POLICY "direct_messages_select_participant" ON direct_messages
  FOR SELECT TO authenticated
  USING (is_dm_participant(conversation_id, auth.uid()));

DROP POLICY IF EXISTS "direct_messages_insert_participant" ON direct_messages;
CREATE POLICY "direct_messages_insert_participant" ON direct_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND is_dm_participant(conversation_id, auth.uid())
  );

DROP POLICY IF EXISTS "direct_messages_update_sender" ON direct_messages;
CREATE POLICY "direct_messages_update_sender" ON direct_messages
  FOR UPDATE TO authenticated
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "direct_messages_delete_sender" ON direct_messages;
CREATE POLICY "direct_messages_delete_sender" ON direct_messages
  FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- Notifications policies
DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
CREATE POLICY "notifications_select_own" ON notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_insert_own" ON notifications;
CREATE POLICY "notifications_insert_own" ON notifications
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_delete_own" ON notifications;
CREATE POLICY "notifications_delete_own" ON notifications
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Reports policies
DROP POLICY IF EXISTS "reports_select_reporter_or_admin" ON reports;
CREATE POLICY "reports_select_reporter_or_admin" ON reports
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid() OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "reports_insert_reporter" ON reports;
CREATE POLICY "reports_insert_reporter" ON reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());

DROP POLICY IF EXISTS "reports_update_admin" ON reports;
CREATE POLICY "reports_update_admin" ON reports
  FOR UPDATE TO authenticated
  USING (is_site_admin(auth.uid()))
  WITH CHECK (is_site_admin(auth.uid()));

-- Moderation actions policies
DROP POLICY IF EXISTS "mod_actions_select_admin" ON moderation_actions;
CREATE POLICY "mod_actions_select_admin" ON moderation_actions
  FOR SELECT TO authenticated
  USING (is_site_admin(auth.uid()) OR moderator_id = auth.uid());

DROP POLICY IF EXISTS "mod_actions_insert_admin" ON moderation_actions;
CREATE POLICY "mod_actions_insert_admin" ON moderation_actions
  FOR INSERT TO authenticated
  WITH CHECK (is_site_admin(auth.uid()) OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'moderator')
  ));

-- Terms versions policies
DROP POLICY IF EXISTS "terms_select_all" ON terms_versions;
CREATE POLICY "terms_select_all" ON terms_versions
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "terms_insert_admin" ON terms_versions;
CREATE POLICY "terms_insert_admin" ON terms_versions
  FOR INSERT TO authenticated
  WITH CHECK (is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "terms_update_admin" ON terms_versions;
CREATE POLICY "terms_update_admin" ON terms_versions
  FOR UPDATE TO authenticated
  USING (is_site_admin(auth.uid()))
  WITH CHECK (is_site_admin(auth.uid()));

-- Terms acceptances policies
DROP POLICY IF EXISTS "terms_acceptances_select_own" ON terms_acceptances;
CREATE POLICY "terms_acceptances_select_own" ON terms_acceptances
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "terms_acceptances_insert_own" ON terms_acceptances;
CREATE POLICY "terms_acceptances_insert_own" ON terms_acceptances
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Audit logs policies
DROP POLICY IF EXISTS "audit_logs_select_admin" ON audit_logs;
CREATE POLICY "audit_logs_select_admin" ON audit_logs
  FOR SELECT TO authenticated
  USING (is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "audit_logs_insert_any" ON audit_logs;
CREATE POLICY "audit_logs_insert_any" ON audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (actor_id = auth.uid());

-- Attachments policies
DROP POLICY IF EXISTS "attachments_select_member" ON attachments;
CREATE POLICY "attachments_select_member" ON attachments
  FOR SELECT TO authenticated
  USING (
    uploader_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM messages
      WHERE messages.id = attachments.message_id
      AND EXISTS (
        SELECT 1 FROM channels
        WHERE channels.id = messages.channel_id
        AND (is_class_member(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
      )
    )
    OR EXISTS (
      SELECT 1 FROM direct_messages
      WHERE direct_messages.id = attachments.dm_message_id
      AND is_dm_participant(direct_messages.conversation_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "attachments_insert_uploader" ON attachments;
CREATE POLICY "attachments_insert_uploader" ON attachments
  FOR INSERT TO authenticated
  WITH CHECK (uploader_id = auth.uid());

DROP POLICY IF EXISTS "attachments_delete_uploader" ON attachments;
CREATE POLICY "attachments_delete_uploader" ON attachments
  FOR DELETE TO authenticated
  USING (uploader_id = auth.uid());

-- Indexes
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON friend_requests (receiver_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_sender ON friend_requests (sender_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_user_a ON friendships (user_a_id);
CREATE INDEX IF NOT EXISTS idx_friendships_user_b ON friendships (user_b_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks (blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_mutes_muter ON user_mutes (muter_id);
CREATE INDEX IF NOT EXISTS idx_dm_participants_conv ON direct_message_participants (conversation_id);
CREATE INDEX IF NOT EXISTS idx_dm_participants_user ON direct_message_participants (user_id);
CREATE INDEX IF NOT EXISTS idx_direct_messages_conv ON direct_messages (conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user ON reports (reported_user_id);
CREATE INDEX IF NOT EXISTS idx_mod_actions_target ON moderation_actions (target_user_id);
CREATE INDEX IF NOT EXISTS idx_terms_acceptances_user ON terms_acceptances (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs (actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_attachments_message ON attachments (message_id);
