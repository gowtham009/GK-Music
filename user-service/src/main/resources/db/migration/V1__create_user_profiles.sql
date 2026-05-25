create table if not exists user_profiles (
  id uuid primary key,
  email text not null unique,
  display_name text not null,
  created_at timestamptz not null
);

