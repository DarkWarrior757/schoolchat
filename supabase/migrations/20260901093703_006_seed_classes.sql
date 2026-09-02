/*
# Seed sample classes, categories, and channels

1. Seed Data
- Create sample classes: Class 7, Class 8, Science Club, Coding Club
- Create sections: 7-A, 7-B, 8-A, 8-B
- Create categories: INFORMATION, ACADEMICS, COMMUNITY, RESOURCES
- Create channels: #announcements, #important-notices, #events, #homework, #science, #mathematics, #english, #general-chat, #discussions, #study-material, #notes, #resources
2. Notes
- These are fake/sample classes for beta testing only
- No real student data is included
- The default school (Greenwood Academy) was created in migration 000
*/

-- Get the default school ID
DO $$
DECLARE
  school_uuid uuid;
  class7 uuid;
  class8 uuid;
  sci_club uuid;
  cod_club uuid;
  cat_info uuid;
  cat_acad uuid;
  cat_comm uuid;
  cat_res uuid;
BEGIN
  SELECT id INTO school_uuid FROM schools LIMIT 1;

  -- Class 7
  INSERT INTO classes (id, school_id, name, description, icon_emoji, icon_color, is_club)
  VALUES (
    gen_random_uuid(), school_uuid, 'Class 7', 'Official communication space for Class 7', '🏫', '#3b82f6', false
  ) RETURNING id INTO class7;

  -- Section 7-A
  INSERT INTO sections (id, class_id, name, description)
  VALUES (gen_random_uuid(), class7, '7-A', 'Section A of Class 7')
  RETURNING id INTO cat_info;

  -- Section 7-B
  INSERT INTO sections (id, class_id, name, description)
  VALUES (gen_random_uuid(), class7, '7-B', 'Section B of Class 7');

  -- Categories for Class 7
  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), class7, 'INFORMATION', 0)
  RETURNING id INTO cat_info;

  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), class7, 'ACADEMICS', 1)
  RETURNING id INTO cat_acad;

  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), class7, 'COMMUNITY', 2)
  RETURNING id INTO cat_comm;

  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), class7, 'RESOURCES', 3)
  RETURNING id INTO cat_res;

  -- Channels for Class 7
  INSERT INTO channels (class_id, category_id, name, description, type, position) VALUES
    (class7, cat_info, 'announcements', 'Official class announcements', 'announcement', 0),
    (class7, cat_info, 'important-notices', 'Important notices from teachers', 'announcement', 1),
    (class7, cat_info, 'events', 'School and class events', 'events', 2),
    (class7, cat_acad, 'homework', 'Homework assignments and discussions', 'homework', 0),
    (class7, cat_acad, 'science', 'Science discussion', 'subject', 1),
    (class7, cat_acad, 'mathematics', 'Mathematics discussion', 'subject', 2),
    (class7, cat_acad, 'english', 'English discussion', 'subject', 3),
    (class7, cat_comm, 'general-chat', 'General class chat', 'chat', 0),
    (class7, cat_comm, 'discussions', 'Open discussions', 'chat', 1),
    (class7, cat_res, 'study-material', 'Approved study materials', 'resources', 0),
    (class7, cat_res, 'notes', 'Class notes', 'resources', 1);

  -- Class 8
  INSERT INTO classes (id, school_id, name, description, icon_emoji, icon_color, is_club)
  VALUES (
    gen_random_uuid(), school_uuid, 'Class 8', 'Official communication space for Class 8', '🏫', '#10b981', false
  ) RETURNING id INTO class8;

  INSERT INTO sections (id, class_id, name, description)
  VALUES (gen_random_uuid(), class8, '8-A', 'Section A of Class 8');
  INSERT INTO sections (id, class_id, name, description)
  VALUES (gen_random_uuid(), class8, '8-B', 'Section B of Class 8');

  -- Categories for Class 8
  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), class8, 'INFORMATION', 0)
  RETURNING id INTO cat_info;
  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), class8, 'ACADEMICS', 1)
  RETURNING id INTO cat_acad;
  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), class8, 'COMMUNITY', 2)
  RETURNING id INTO cat_comm;

  INSERT INTO channels (class_id, category_id, name, description, type, position) VALUES
    (class8, cat_info, 'announcements', 'Official class announcements', 'announcement', 0),
    (class8, cat_info, 'events', 'School and class events', 'events', 1),
    (class8, cat_acad, 'homework', 'Homework assignments and discussions', 'homework', 0),
    (class8, cat_acad, 'science', 'Science discussion', 'subject', 1),
    (class8, cat_acad, 'mathematics', 'Mathematics discussion', 'subject', 2),
    (class8, cat_comm, 'general-chat', 'General class chat', 'chat', 0);

  -- Science Club
  INSERT INTO classes (id, school_id, name, description, icon_emoji, icon_color, is_club)
  VALUES (
    gen_random_uuid(), school_uuid, 'Science Club', 'For science enthusiasts', '🔬', '#8b5cf6', true
  ) RETURNING id INTO sci_club;

  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), sci_club, 'INFORMATION', 0)
  RETURNING id INTO cat_info;
  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), sci_club, 'COMMUNITY', 1)
  RETURNING id INTO cat_comm;

  INSERT INTO channels (class_id, category_id, name, description, type, position) VALUES
    (sci_club, cat_info, 'announcements', 'Club announcements', 'announcement', 0),
    (sci_club, cat_comm, 'general-chat', 'General club chat', 'chat', 0),
    (sci_club, cat_comm, 'experiments', 'Discuss experiments', 'subject', 1);

  -- Coding Club
  INSERT INTO classes (id, school_id, name, description, icon_emoji, icon_color, is_club)
  VALUES (
    gen_random_uuid(), school_uuid, 'Coding Club', 'For coding enthusiasts', '💻', '#f59e0b', true
  ) RETURNING id INTO cod_club;

  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), cod_club, 'INFORMATION', 0)
  RETURNING id INTO cat_info;
  INSERT INTO categories (id, class_id, name, position)
  VALUES (gen_random_uuid(), cod_club, 'COMMUNITY', 1)
  RETURNING id INTO cat_comm;

  INSERT INTO channels (class_id, category_id, name, description, type, position) VALUES
    (cod_club, cat_info, 'announcements', 'Club announcements', 'announcement', 0),
    (cod_club, cat_comm, 'general-chat', 'General club chat', 'chat', 0),
    (cod_club, cat_comm, 'projects', 'Share and discuss projects', 'subject', 1);
END;
$$;
