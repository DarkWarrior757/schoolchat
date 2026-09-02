export type Role = 'student' | 'teacher' | 'moderator' | 'admin';
export type Presence = 'online' | 'away' | 'offline';
export type ThemeMode = 'dark' | 'light' | 'system';

export interface Profile {
  id: string;
  email: string;
  display_name: string;
  username: string;
  role: Role;
  avatar_url: string | null;
  avatar_color: string;
  status: Presence;
  bio: string | null;
}

export interface SchoolClass {
  id: string;
  name: string;
  description: string;
  icon_emoji: string;
  icon_color: string;
  is_club: boolean;
}

export interface Section {
  id: string;
  class_id: string;
  name: string;
  description: string;
}

export interface Channel {
  id: string;
  class_id: string;
  category_id: string | null;
  name: string;
  description: string;
  type: string;
  position: number;
}

export interface Category {
  id: string;
  class_id: string;
  name: string;
  position: number;
}

export interface ClassMember {
  id: string;
  class_id: string;
  user_id: string;
  role: Role;
  section_id: string | null;
  profiles?: Profile;
}

export interface Message {
  id: string;
  channel_id: string;
  author_id: string;
  content: string;
  reply_to: string | null;
  is_edited: boolean;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
  profiles?: Profile;
}

export interface FriendRequest {
  id: string;
  sender_id: string;
  receiver_id: string;
  status: string;
  created_at: string;
  profiles?: Profile;
}

export interface Friendship {
  id: string;
  user_a_id: string;
  user_b_id: string;
  created_at: string;
}

export interface Notification {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  actor_id: string | null;
  resource_id: string | null;
  is_read: boolean;
  created_at: string;
}

export interface DirectMessage {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  is_edited: boolean;
  is_deleted: boolean;
  reply_to: string | null;
  created_at: string;
  profiles?: Profile;
}

export interface DMConversation {
  id: string;
  other_user: Profile;
  last_message?: string;
  last_at?: string;
}

export interface Report {
  id: string;
  reporter_id: string;
  reported_user_id: string | null;
  message_id: string | null;
  reason: string;
  description: string;
  status: string;
  created_at: string;
  profiles?: Profile;
  reported_profile?: Profile;
}

export interface TermsVersion {
  id: string;
  version: string;
  title: string;
  content: string;
  is_active: boolean;
  created_at: string;
}

export interface UserBlock {
  id: string;
  blocker_id: string;
  blocked_id: string;
  profiles?: Profile;
}
