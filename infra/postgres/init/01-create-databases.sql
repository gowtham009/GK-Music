do
$$
begin
  if not exists (select 1 from pg_roles where rolname = 'auth') then
    create role auth login password 'auth';
  end if;
  if not exists (select 1 from pg_roles where rolname = 'user') then
    create role "user" login password 'user';
  end if;
  if not exists (select 1 from pg_roles where rolname = 'music') then
    create role music login password 'music';
  end if;
end
$$;

select 'create database authdb owner auth'
where not exists (select from pg_database where datname = 'authdb')\gexec

select 'create database userdb owner "user"'
where not exists (select from pg_database where datname = 'userdb')\gexec

select 'create database musicdb owner music'
where not exists (select from pg_database where datname = 'musicdb')\gexec

