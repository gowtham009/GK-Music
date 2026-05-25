create table if not exists auth_users (
  id uuid primary key,
  email text not null unique,
  password_hash text not null,
  display_name text not null,
  created_at timestamptz not null
);

