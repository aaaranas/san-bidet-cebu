-- SanBidet Cebu — data integrity + row level security
--
-- Run this against your Supabase project (SQL Editor, or `supabase db push`).
-- It is written to be idempotent so it is safe to re-run.
--
-- What it fixes:
--   1. Ratings were a client-side read-modify-write across two round trips, so
--      simultaneous raters silently overwrote each other.
--   2. Nothing recorded WHO rated, so one person could rate the same bidet an
--      unlimited number of times and move the average arbitrarily.
--   3. Submissions had no owner, so nothing could be attributed or moderated
--      per user.
--   4. Without RLS, the anon key allowed anyone to update or delete any row.

-- ---------------------------------------------------------------------------
-- 0. Prerequisites
-- ---------------------------------------------------------------------------

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1. Profiles — one row per auth user, carrying the role
-- ---------------------------------------------------------------------------

-- A profiles table may already exist with a different shape (an earlier
-- version of this project shipped one with only id + role), in which case
-- "create table if not exists" is a silent no-op and later statements fail on
-- a missing column. So: create it if absent, then reconcile the columns.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade
);

alter table public.profiles
  add column if not exists username   text,
  add column if not exists email      text,
  add column if not exists role       text not null default 'user',
  add column if not exists created_at timestamptz not null default now();

-- The pre-existing role column is nullable; is_admin() copes with NULL, but
-- making it NOT NULL keeps the check constraint below meaningful (a CHECK
-- passes on NULL, so nullable + CHECK would not actually constrain anything).
update public.profiles set role = 'user' where role is null;
alter table public.profiles alter column role set default 'user';
alter table public.profiles alter column role set not null;

-- Unique username, added separately so it works on a pre-existing table.
-- Postgres allows multiple NULLs, so existing rows without one are fine.
create unique index if not exists profiles_username_key
  on public.profiles (username);

-- Constrain role to the known values, only if that constraint is not there.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname  = 'profiles_role_check'
  ) then
    -- Normalise anything unexpected first, or the constraint will not validate.
    update public.profiles set role = 'user'
    where role is null or role not in ('user', 'admin');

    alter table public.profiles
      add constraint profiles_role_check check (role in ('user', 'admin'));
  end if;
end
$$;

-- Picks a username that is not already taken, appending a short suffix on
-- collision. Two people whose emails share a local part (juan@a.com and
-- juan@b.com) would otherwise collide on the unique index.
create or replace function public.unique_username(p_desired text, p_user uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base      text := nullif(trim(p_desired), '');
  v_candidate text;
begin
  if v_base is null then
    v_base := 'user';
  end if;

  v_candidate := v_base;
  for i in 1..5 loop
    exit when not exists (
      select 1 from public.profiles
      where username = v_candidate and id <> p_user
    );
    v_candidate := v_base || '_' || substr(replace(p_user::text, '-', ''), 1, 4 + i);
  end loop;

  -- Give up rather than fail the signup outright; the user can set one later.
  if exists (
    select 1 from public.profiles where username = v_candidate and id <> p_user
  ) then
    return null;
  end if;

  return v_candidate;
end;
$$;

-- Auto-create the profile row on signup. Its absence was what made
-- isAdmin() throw and surface as "invalid email or password".
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, email)
  values (
    new.id,
    public.unique_username(
      coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
      new.id
    ),
    new.email
  )
  on conflict (id) do nothing;
  return new;
exception
  -- A profile is not worth failing a signup over; getRole() now tolerates a
  -- missing row and falls back to 'user'.
  when others then
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill anyone who signed up before this migration. Ids first, so a
-- username collision can never block the row itself from being created.
insert into public.profiles (id)
select u.id from auth.users u
on conflict (id) do nothing;

update public.profiles p
set username = public.unique_username(
      coalesce(
        (select u.raw_user_meta_data ->> 'username' from auth.users u where u.id = p.id),
        split_part((select u.email from auth.users u where u.id = p.id), '@', 1)
      ),
      p.id
    )
where p.username is null;

update public.profiles p
set email = (select u.email from auth.users u where u.id = p.id)
where p.email is null;

-- ---------------------------------------------------------------------------
-- 2. Bidets — ownership column
-- ---------------------------------------------------------------------------

-- Fail loudly and early if bidets.id is not a uuid: the bidet_ratings foreign
-- key and submit_bidet_rating(uuid, ...) below both depend on it, and a
-- mismatch would otherwise surface as a confusing error much further down.
do $$
declare
  v_type text;
begin
  select data_type into v_type
  from information_schema.columns
  where table_schema = 'public' and table_name = 'bidets' and column_name = 'id';

  if v_type is null then
    raise exception 'Table public.bidets not found. Create it before running this migration.';
  end if;

  if v_type <> 'uuid' then
    raise exception
      'public.bidets.id is %, but this migration assumes uuid. Tell the maintainer so the types can be matched.',
      v_type;
  end if;
end
$$;

-- Ownership lives in the existing `submitted_by` column. An earlier draft of
-- this migration added a second `user_id` column, which would have split
-- ownership across two places.
alter table public.bidets
  add column if not exists submitted_by uuid references auth.users (id) on delete set null;

-- Rating aggregate columns, in case any are missing on an older schema.
alter table public.bidets
  add column if not exists status               text   default 'pending',
  add column if not exists rating               double precision default 0,
  add column if not exists rating_count         integer default 0,
  add column if not exists cleanliness_rating   double precision default 0,
  add column if not exists pressure_rating      double precision default 0,
  add column if not exists accessibility_rating double precision default 0,
  add column if not exists privacy_rating       double precision default 0,
  add column if not exists image_url            text,
  add column if not exists created_at           timestamp default now();

-- status is nullable today. A NULL would be invisible to the select policy
-- below (NULL = 'approved' is unknown, not true), so normalise and pin it.
update public.bidets set status = 'pending' where status is null;
alter table public.bidets alter column status set default 'pending';
alter table public.bidets alter column status set not null;

create index if not exists bidets_status_idx       on public.bidets (status);
create index if not exists bidets_submitted_by_idx on public.bidets (submitted_by);

-- ---------------------------------------------------------------------------
-- 3. Per-user ratings
-- ---------------------------------------------------------------------------

create table if not exists public.bidet_ratings (
  bidet_id      uuid not null references public.bidets (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  cleanliness   numeric(2,1) not null check (cleanliness   between 1 and 5),
  pressure      numeric(2,1) not null check (pressure      between 1 and 5),
  accessibility numeric(2,1) not null check (accessibility between 1 and 5),
  privacy       numeric(2,1) not null check (privacy       between 1 and 5),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  -- One rating per person per bidet. Re-rating updates in place.
  primary key (bidet_id, user_id)
);

-- ---------------------------------------------------------------------------
-- 4. Atomic rating submission
-- ---------------------------------------------------------------------------

-- Upserts the caller's rating and recomputes every average from the source
-- rows inside a single transaction. Averages are therefore always exactly
-- consistent with bidet_ratings, and concurrent callers cannot clobber
-- each other.
create or replace function public.submit_bidet_rating(
  p_bidet_id      uuid,
  p_cleanliness   numeric,
  p_pressure      numeric,
  p_accessibility numeric,
  p_privacy       numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'You must be signed in to rate a bidet.'
      using errcode = '42501';
  end if;

  insert into public.bidet_ratings as r
    (bidet_id, user_id, cleanliness, pressure, accessibility, privacy)
  values
    (p_bidet_id, v_user, p_cleanliness, p_pressure, p_accessibility, p_privacy)
  on conflict (bidet_id, user_id) do update
    set cleanliness   = excluded.cleanliness,
        pressure      = excluded.pressure,
        accessibility = excluded.accessibility,
        privacy       = excluded.privacy,
        updated_at    = now();

  update public.bidets b
  set rating               = agg.overall,
      rating_count         = agg.n,
      cleanliness_rating   = agg.cleanliness,
      pressure_rating      = agg.pressure,
      accessibility_rating = agg.accessibility,
      privacy_rating       = agg.privacy
  from (
    select count(*)                                              as n,
           avg(cleanliness)                                      as cleanliness,
           avg(pressure)                                         as pressure,
           avg(accessibility)                                    as accessibility,
           avg(privacy)                                          as privacy,
           avg((cleanliness + pressure + accessibility + privacy) / 4.0) as overall
    from public.bidet_ratings
    where bidet_id = p_bidet_id
  ) agg
  where b.id = p_bidet_id;
end;
$$;

grant execute on function public.submit_bidet_rating(uuid, numeric, numeric, numeric, numeric)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Row level security
-- ---------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

alter table public.bidets        enable row level security;
alter table public.bidet_ratings enable row level security;
alter table public.profiles      enable row level security;

-- bidets ---------------------------------------------------------------------
drop policy if exists bidets_select_approved on public.bidets;
create policy bidets_select_approved on public.bidets
  for select
  using (
    status = 'approved'
    or submitted_by = auth.uid()
    or public.is_admin()
  );

drop policy if exists bidets_insert_own on public.bidets;
create policy bidets_insert_own on public.bidets
  for insert to authenticated
  with check (
    submitted_by = auth.uid()
    -- New submissions always start pending; only an admin can publish.
    and status = 'pending'
  );

drop policy if exists bidets_update_admin on public.bidets;
create policy bidets_update_admin on public.bidets
  for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists bidets_delete_admin on public.bidets;
create policy bidets_delete_admin on public.bidets
  for delete using (public.is_admin());

-- bidet_ratings --------------------------------------------------------------
drop policy if exists ratings_select_all on public.bidet_ratings;
create policy ratings_select_all on public.bidet_ratings
  for select using (true);

-- Writes go exclusively through submit_bidet_rating(); no direct client insert.
drop policy if exists ratings_no_direct_write on public.bidet_ratings;

-- profiles -------------------------------------------------------------------
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles
  for select using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid())
  -- Role escalation is blocked: a user cannot make themselves an admin.
  with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 6. Storage policies for the bidet-images bucket
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('bidet-images', 'bidet-images', true)
on conflict (id) do nothing;

drop policy if exists bidet_images_read on storage.objects;
create policy bidet_images_read on storage.objects
  for select using (bucket_id = 'bidet-images');

drop policy if exists bidet_images_write on storage.objects;
create policy bidet_images_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'bidet-images');

-- ---------------------------------------------------------------------------
-- 7. Promote your own account to admin (run manually, once)
-- ---------------------------------------------------------------------------
--
--   update public.profiles set role = 'admin'
--   where id = (select id from auth.users where email = 'you@example.com');
