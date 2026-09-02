/*
# Create friendship auto-creation trigger and seed data

1. Triggers
- `handle_friend_request_accept`: when a friend_request status changes to 'accepted', automatically create a friendship record (with user_a < user_b ordering)
2. Seed Data
- Insert default terms version (v1.0) with placeholder content
*/

-- Function to create friendship when request is accepted
CREATE OR REPLACE FUNCTION public.handle_friend_request_accept()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  user_a uuid;
  user_b uuid;
BEGIN
  IF NEW.status = 'accepted' AND (OLD IS NULL OR OLD.status != 'accepted') THEN
    -- Ensure consistent ordering: smaller UUID first
    IF NEW.sender_id < NEW.receiver_id THEN
      user_a := NEW.sender_id;
      user_b := NEW.receiver_id;
    ELSE
      user_a := NEW.receiver_id;
      user_b := NEW.sender_id;
    END IF;

    INSERT INTO friendships (user_a_id, user_b_id)
    VALUES (user_a, user_b)
    ON CONFLICT (user_a_id, user_b_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_friend_request_accepted ON friend_requests;
CREATE TRIGGER on_friend_request_accepted
  AFTER UPDATE ON friend_requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_friend_request_accept();

-- Seed default terms version
INSERT INTO terms_versions (version, title, content, is_active)
VALUES (
  '1.0',
  'SchoolChat Beta Terms & Conditions',
  '[PLACEHOLDER — This text must be replaced with your school''s officially approved Terms & Conditions before deployment.]

Welcome to SchoolChat Beta. By using this platform, you agree to the following terms:

1. Acceptable Use
   - SchoolChat is provided by your school for educational communication.
   - You agree to use the platform respectfully and responsibly.
   - Harassment, bullying, hate speech, and inappropriate content are strictly prohibited.

2. Privacy
   - Your display name, username, and messages are visible to authorized members of your school community.
   - The school administration may access messages for moderation and safety purposes.
   - See the Privacy Notice for details on data collection and usage.

3. Account Security
   - You are responsible for keeping your login credentials secure.
   - Do not share your account with others.

4. Moderation
   - The school administration reserves the right to moderate, remove, or restrict access to content or accounts that violate these terms.

5. Beta Status
   - SchoolChat is currently in beta. Features may change, and data may be reset during testing.

6. Contact
   - For questions about these terms, contact your school administrator.',
  true
)
ON CONFLICT (version) DO NOTHING;
