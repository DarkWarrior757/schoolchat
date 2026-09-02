/*
# Create classes, sections, categories, channels, and membership tables

1. New Tables
- `classes`: school classes (e.g., Class 7, Science Club) with icon, description, owner
- `sections`: sections within a class (e.g., 7-A, 7-B) — optional, a class can have sections or be a club
- `categories`: channel categories within a class/section (e.g., INFORMATION, ACADEMICS)
- `channels`: channels within a category (e.g., #announcements, #science) with type and permissions
- `class_members`: membership linking users to classes with role (student/teacher/admin)
- `channel_members`: optional per-channel membership overrides
2. Security
- RLS enabled on all tables
- Users can only see classes they are members of
- Users can only see channels in classes they are members of
- Only teachers/admins can create channels, categories
- Only admins can create classes
3. Indexes on foreign keys and frequently queried columns
*/

-- Classes table
CREATE TABLE IF NOT EXISTS classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  description text DEFAULT '',
  icon_emoji text DEFAULT '🏫',
  icon_color text DEFAULT '#3b82f6',
  is_club boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Sections table (sub-groups within a class)
CREATE TABLE IF NOT EXISTS sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  description text DEFAULT '',
  created_at timestamptz DEFAULT now()
);

-- Categories table (channel groupings within a class/section)
CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  section_id uuid REFERENCES sections(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  position int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Channels table
CREATE TABLE IF NOT EXISTS channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  section_id uuid REFERENCES sections(id) ON DELETE CASCADE,
  category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  name text NOT NULL DEFAULT '',
  description text DEFAULT '',
  type text NOT NULL DEFAULT 'chat' CHECK (type IN ('announcement', 'homework', 'chat', 'subject', 'resources', 'events', 'read_only')),
  position int NOT NULL DEFAULT 0,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Class members table
CREATE TABLE IF NOT EXISTS class_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id uuid NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'admin')),
  section_id uuid REFERENCES sections(id) ON DELETE SET NULL,
  joined_at timestamptz DEFAULT now(),
  UNIQUE(class_id, user_id)
);

-- Channel members table (optional per-channel overrides, mainly for read-only channels)
CREATE TABLE IF NOT EXISTS channel_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id uuid NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  can_write boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(channel_id, user_id)
);

-- Enable RLS
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_members ENABLE ROW LEVEL SECURITY;

-- Helper function: is user a member of a class?
CREATE OR REPLACE FUNCTION public.is_class_member(class_uuid uuid, user_uuid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM class_members
    WHERE class_id = class_uuid AND user_id = user_uuid
  );
$$;

-- Helper function: is user a teacher or admin of a class?
CREATE OR REPLACE FUNCTION public.is_class_staff(class_uuid uuid, user_uuid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM class_members
    WHERE class_id = class_uuid AND user_id = user_uuid
    AND role IN ('teacher', 'admin')
  );
$$;

-- Helper function: is user a site admin?
CREATE OR REPLACE FUNCTION public.is_site_admin(user_uuid uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = user_uuid AND role = 'admin'
  );
$$;

-- Classes policies
DROP POLICY IF EXISTS "classes_select_member" ON classes;
CREATE POLICY "classes_select_member" ON classes
  FOR SELECT TO authenticated
  USING (is_class_member(id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "classes_insert_admin" ON classes;
CREATE POLICY "classes_insert_admin" ON classes
  FOR INSERT TO authenticated
  WITH CHECK (is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "classes_update_admin" ON classes;
CREATE POLICY "classes_update_admin" ON classes
  FOR UPDATE TO authenticated
  USING (is_site_admin(auth.uid()) OR is_class_staff(id, auth.uid()))
  WITH CHECK (is_site_admin(auth.uid()) OR is_class_staff(id, auth.uid()));

DROP POLICY IF EXISTS "classes_delete_admin" ON classes;
CREATE POLICY "classes_delete_admin" ON classes
  FOR DELETE TO authenticated
  USING (is_site_admin(auth.uid()));

-- Sections policies
DROP POLICY IF EXISTS "sections_select_member" ON sections;
CREATE POLICY "sections_select_member" ON sections
  FOR SELECT TO authenticated
  USING (is_class_member(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "sections_insert_staff" ON sections;
CREATE POLICY "sections_insert_staff" ON sections
  FOR INSERT TO authenticated
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "sections_update_staff" ON sections;
CREATE POLICY "sections_update_staff" ON sections
  FOR UPDATE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()))
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "sections_delete_staff" ON sections;
CREATE POLICY "sections_delete_staff" ON sections
  FOR DELETE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

-- Categories policies
DROP POLICY IF EXISTS "categories_select_member" ON categories;
CREATE POLICY "categories_select_member" ON categories
  FOR SELECT TO authenticated
  USING (is_class_member(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "categories_insert_staff" ON categories;
CREATE POLICY "categories_insert_staff" ON categories
  FOR INSERT TO authenticated
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "categories_update_staff" ON categories;
CREATE POLICY "categories_update_staff" ON categories
  FOR UPDATE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()))
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "categories_delete_staff" ON categories;
CREATE POLICY "categories_delete_staff" ON categories
  FOR DELETE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

-- Channels policies
DROP POLICY IF EXISTS "channels_select_member" ON channels;
CREATE POLICY "channels_select_member" ON channels
  FOR SELECT TO authenticated
  USING (is_class_member(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "channels_insert_staff" ON channels;
CREATE POLICY "channels_insert_staff" ON channels
  FOR INSERT TO authenticated
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "channels_update_staff" ON channels;
CREATE POLICY "channels_update_staff" ON channels
  FOR UPDATE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()))
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "channels_delete_staff" ON channels;
CREATE POLICY "channels_delete_staff" ON channels
  FOR DELETE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

-- Class members policies
DROP POLICY IF EXISTS "class_members_select_member" ON class_members;
CREATE POLICY "class_members_select_member" ON class_members
  FOR SELECT TO authenticated
  USING (is_class_member(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "class_members_insert_staff" ON class_members;
CREATE POLICY "class_members_insert_staff" ON class_members
  FOR INSERT TO authenticated
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "class_members_update_staff" ON class_members;
CREATE POLICY "class_members_update_staff" ON class_members
  FOR UPDATE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()))
  WITH CHECK (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()));

DROP POLICY IF EXISTS "class_members_delete_staff" ON class_members;
CREATE POLICY "class_members_delete_staff" ON class_members
  FOR DELETE TO authenticated
  USING (is_class_staff(class_id, auth.uid()) OR is_site_admin(auth.uid()) OR user_id = auth.uid());

-- Channel members policies
DROP POLICY IF EXISTS "channel_members_select_member" ON channel_members;
CREATE POLICY "channel_members_select_member" ON channel_members
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = channel_id
      AND (is_class_member(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

DROP POLICY IF EXISTS "channel_members_insert_staff" ON channel_members;
CREATE POLICY "channel_members_insert_staff" ON channel_members
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = channel_id
      AND (is_class_staff(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

DROP POLICY IF EXISTS "channel_members_update_staff" ON channel_members;
CREATE POLICY "channel_members_update_staff" ON channel_members
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = channel_id
      AND (is_class_staff(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = channel_id
      AND (is_class_staff(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

DROP POLICY IF EXISTS "channel_members_delete_staff" ON channel_members;
CREATE POLICY "channel_members_delete_staff" ON channel_members
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM channels
      WHERE channels.id = channel_id
      AND (is_class_staff(channels.class_id, auth.uid()) OR is_site_admin(auth.uid()))
    )
  );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_classes_school_id ON classes (school_id);
CREATE INDEX IF NOT EXISTS idx_sections_class_id ON sections (class_id);
CREATE INDEX IF NOT EXISTS idx_categories_class_id ON categories (class_id);
CREATE INDEX IF NOT EXISTS idx_categories_section_id ON categories (section_id);
CREATE INDEX IF NOT EXISTS idx_channels_class_id ON channels (class_id);
CREATE INDEX IF NOT EXISTS idx_channels_section_id ON channels (section_id);
CREATE INDEX IF NOT EXISTS idx_channels_category_id ON channels (category_id);
CREATE INDEX IF NOT EXISTS idx_class_members_class_id ON class_members (class_id);
CREATE INDEX IF NOT EXISTS idx_class_members_user_id ON class_members (user_id);
CREATE INDEX IF NOT EXISTS idx_channel_members_channel_id ON channel_members (channel_id);
CREATE INDEX IF NOT EXISTS idx_channel_members_user_id ON channel_members (user_id);
