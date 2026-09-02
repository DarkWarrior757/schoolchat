# SchoolChat Beta

Connect. Communicate. Learn.

SchoolChat is a school-approved communication workspace for classes, clubs, teachers, and students. It provides class channels, persistent messages, school friends, notifications, and privacy-conscious member access.

## Stack

- React + TypeScript + Vite
- Supabase Auth, PostgreSQL, Row Level Security, and Realtime
- Tailwind CSS
- Lucide icons

## Local setup

1. Install dependencies with `npm install`.
2. Copy `.env.example` to `.env` and provide the Supabase project URL and anonymous key.
3. Apply the database migrations in the Supabase project in filename order.
4. Start the Vite development server with `npm run dev`.

## Database and access

The database contains protected profiles, schools, classes, sections, categories, channels, class membership, messages, friend relationships, direct-message containers, notifications, reports, moderation actions, terms, attachments, and audit logs. RLS policies scope access to authenticated members and prevent students from changing roles or accessing unrelated class conversations.

New accounts are students by default. An authorized school administrator must assign class membership and elevated roles.

## Production and mobile preparation

Run `npm run build` for the production bundle. The web client uses the same Supabase services that a future Capacitor Android wrapper can use, so authentication, database, realtime, and storage do not need a separate mobile backend.

## Safety

Replace the placeholder Terms & Conditions content with wording approved by the school before production use. Keep storage buckets private, review moderation policies with school leadership, and never expose service-role credentials in the browser.
