/*
# Create schools table

1. New Tables
- `schools`: top-level school entity with name, description, DM permission setting
2. Security
- RLS enabled
- Any authenticated user can read schools
*/

CREATE TABLE IF NOT EXISTS schools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL DEFAULT 'Default School',
  description text DEFAULT '',
  dm_permission text NOT NULL DEFAULT 'friends' CHECK (dm_permission IN ('friends', 'school', 'disabled')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "schools_select_all" ON schools;
CREATE POLICY "schools_select_all" ON schools
  FOR SELECT TO authenticated USING (true);

-- Insert a default school
INSERT INTO schools (name, description, dm_permission)
VALUES ('Greenwood Academy', 'Default school for SchoolChat Beta', 'friends')
ON CONFLICT DO NOTHING;
