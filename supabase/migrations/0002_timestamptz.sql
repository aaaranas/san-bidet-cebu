-- SanBidet Cebu — make timestamps timezone-aware
--
-- Run after 0001. Idempotent: re-running is a no-op once the types are right.
--
-- Why:
--   bidets.created_at and profiles.created_at are `timestamp without time
--   zone`. Postgres now() writes UTC into them, but the value carries no zone,
--   so Dart's DateTime.tryParse reads the string as LOCAL time. For a user in
--   Cebu (UTC+8) that shifts every "Added" date back eight hours, which shows
--   the wrong calendar day for anything created before 08:00 local.
--
-- The USING clause states that the stored values are UTC, which is what now()
-- actually wrote. Without it Postgres would assume the server's timezone and
-- shift the data.

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'bidets'
      and column_name  = 'created_at'
      and data_type    = 'timestamp without time zone'
  ) then
    alter table public.bidets
      alter column created_at type timestamptz
      using created_at at time zone 'UTC';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'profiles'
      and column_name  = 'created_at'
      and data_type    = 'timestamp without time zone'
  ) then
    alter table public.profiles
      alter column created_at type timestamptz
      using created_at at time zone 'UTC';
  end if;
end
$$;

-- Defaults follow the new type.
alter table public.bidets   alter column created_at set default now();
alter table public.profiles alter column created_at set default now();

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
--
-- The map and dashboard subscribe with Supabase Realtime (`.stream()`), which
-- only delivers rows for tables in the `supabase_realtime` publication.
-- Without this the stream connects, stays silent, and the UI shows "0 bidets"
-- forever with no error anywhere.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'bidets'
     )
  then
    alter publication supabase_realtime add table public.bidets;
  end if;
end
$$;

-- Realtime sends old-row data for updates/deletes only with REPLICA IDENTITY
-- FULL; without it a row leaving the stream cannot be matched back.
alter table public.bidets replica identity full;
