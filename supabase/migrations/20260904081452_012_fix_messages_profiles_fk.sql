/*
# Fix message joins by adding FKs to profiles

The messages.author_id and direct_messages.sender_id columns reference auth.users(id),
but PostgREST needs a direct FK to profiles(id) to resolve the `select('*, profiles(*)')` join.
Without it, message inserts fail because the returning select can't resolve the profiles relationship.
*/

-- Add FK from messages.author_id to profiles.id
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'messages_author_id_profiles_fkey'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT messages_author_id_profiles_fkey
      FOREIGN KEY (author_id) REFERENCES profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Add FK from direct_messages.sender_id to profiles.id
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'direct_messages_sender_id_profiles_fkey'
  ) THEN
    ALTER TABLE direct_messages
      ADD CONSTRAINT direct_messages_sender_id_profiles_fkey
      FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;
  END IF;
END $$;
