-- SanBidet Cebu — reports, access details, and a real moderation lifecycle
--
-- Run after 0002. Idempotent: safe to re-run.
--
-- What it adds:
--   1. Access reality — is it customer-only, when is it open, does it cost.
--      "3rd floor near the cinemas" does not tell you whether you can walk in.
--   2. A rejected state with a reason. Rejecting used to hard-delete the row,
--      so the contributor got no feedback and nothing stopped them adding the
--      same place again tomorrow.
--   3. Reports. The app catalogues physical things that close and break; with
--      no way to flag stale entries the data can only rot.
--   4. A submitted_by -> profiles foreign key, so the API can embed the
--      contributor's username and submissions can finally be attributed.
--   5. A proximity lookup, so the add form can catch duplicates before they
--      are created rather than after.

-- ---------------------------------------------------------------------------
-- 1. Access details
-- ---------------------------------------------------------------------------

alter table public.bidets
  add column if not exists access_type text not null default 'public',
  add column if not exists hours_note  text,
  add column if not exists fee_note    text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bidets'::regclass
      and conname  = 'bidets_access_type_check'
  ) then
    update public.bidets set access_type = 'public'
    where access_type is null
       or access_type not in ('public', 'customer', 'staff');

    alter table public.bidets
      add constraint bidets_access_type_check
      check (access_type in ('public', 'customer', 'staff'));
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 2. Moderation lifecycle
-- ---------------------------------------------------------------------------

alter table public.bidets
  add column if not exists rejection_reason text,
  add column if not exists reviewed_by      uuid references auth.users (id) on delete set null,
  add column if not exists reviewed_at      timestamptz;

-- `status` previously allowed only pending/approved by convention, with no
-- constraint. Pin the three states now that rejection is a real outcome.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bidets'::regclass
      and conname  = 'bidets_status_check'
  ) then
    update public.bidets set status = 'pending'
    where status is null
       or status not in ('pending', 'approved', 'rejected');

    alter table public.bidets
      add constraint bidets_status_check
      check (status in ('pending', 'approved', 'rejected'));
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Attribution
-- ---------------------------------------------------------------------------

-- Point submitted_by at `profiles` instead of `auth.users`. PostgREST can only
-- embed across a declared foreign key, and `auth.users` is not exposed to the
-- API — which is why the contributor's name could never be joined in.
do $$
declare
  v_conname text;
begin
  -- Orphans would block the new constraint. Every auth user has a profile row
  -- (0001 creates one on signup and backfills), so this should be a no-op.
  update public.bidets b
  set submitted_by = null
  where submitted_by is not null
    and not exists (select 1 from public.profiles p where p.id = b.submitted_by);

  select conname into v_conname
  from pg_constraint
  where conrelid = 'public.bidets'::regclass
    and contype = 'f'
    and conkey = array[
      (select attnum from pg_attribute
       where attrelid = 'public.bidets'::regclass and attname = 'submitted_by')
    ]::smallint[]
  limit 1;

  if v_conname is not null and v_conname <> 'bidets_submitted_by_profile_fkey' then
    execute format('alter table public.bidets drop constraint %I', v_conname);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bidets'::regclass
      and conname  = 'bidets_submitted_by_profile_fkey'
  ) then
    alter table public.bidets
      add constraint bidets_submitted_by_profile_fkey
      foreign key (submitted_by) references public.profiles (id) on delete set null;
  end if;
end
$$;

-- Contributor names must be readable to show attribution. This exposes only
-- id/username/role — never email.
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_public on public.profiles
  for select using (true);

revoke select on public.profiles from anon, authenticated;
grant select (id, username, role, created_at) on public.profiles
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Reports
-- ---------------------------------------------------------------------------

create table if not exists public.bidet_reports (
  id         uuid primary key default gen_random_uuid(),
  bidet_id   uuid not null references public.bidets (id) on delete cascade,
  user_id    uuid references public.profiles (id) on delete set null,
  kind       text not null check (
               kind in ('gone', 'broken', 'inaccurate', 'duplicate', 'other')),
  note       text,
  resolved   boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists bidet_reports_open_idx
  on public.bidet_reports (bidet_id) where not resolved;

alter table public.bidet_reports enable row level security;

drop policy if exists reports_insert_signed_in on public.bidet_reports;
create policy reports_insert_signed_in on public.bidet_reports
  for insert to authenticated
  with check (user_id = auth.uid());

-- Reports are moderation data, not public content: you see your own, admins
-- see everything.
drop policy if exists reports_select_own_or_admin on public.bidet_reports;
create policy reports_select_own_or_admin on public.bidet_reports
  for select using (user_id = auth.uid() or public.is_admin());

drop policy if exists reports_update_admin on public.bidet_reports;
create policy reports_update_admin on public.bidet_reports
  for update using (public.is_admin()) with check (public.is_admin());

-- Open-report count per bidet, so the moderation queue can be ordered by what
-- needs attention. security definer: the count is public, the rows are not.
create or replace function public.open_report_counts()
returns table (bidet_id uuid, open_reports bigint)
language sql
stable
security definer
set search_path = public
as $$
  select bidet_id, count(*)
  from public.bidet_reports
  where not resolved
  group by bidet_id;
$$;

grant execute on function public.open_report_counts() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Visibility of your own submissions
-- ---------------------------------------------------------------------------

-- Rejected rows stay visible to their author (that is the whole point of
-- keeping them) and to admins, but never to everyone else.
drop policy if exists bidets_select_approved on public.bidets;
create policy bidets_select_approved on public.bidets
  for select
  using (
    status = 'approved'
    or submitted_by = auth.uid()
    or public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- 6. Duplicate guard
-- ---------------------------------------------------------------------------

-- Bidets within `p_radius_m` of a point, nearest first. Haversine in SQL so no
-- PostGIS dependency; the bounding box prefilter keeps it index-friendly.
create or replace function public.bidets_near(
  p_lat      double precision,
  p_lng      double precision,
  p_radius_m double precision default 120
)
returns table (
  id         uuid,
  place_name text,
  floor      text,
  type       text,
  status     text,
  distance_m double precision
)
language sql
stable
security definer
set search_path = public
as $$
  with box as (
    select p_radius_m / 111320.0 as d_lat,
           p_radius_m / (111320.0 * greatest(cos(radians(p_lat)), 0.01)) as d_lng
  )
  select b.id,
         b.place_name,
         b.floor,
         b.type,
         b.status,
         2 * 6371000 * asin(
           sqrt(
             power(sin(radians(b.latitude - p_lat) / 2), 2) +
             cos(radians(p_lat)) * cos(radians(b.latitude)) *
             power(sin(radians(b.longitude - p_lng) / 2), 2)
           )
         ) as distance_m
  from public.bidets b, box
  where b.latitude between p_lat - box.d_lat and p_lat + box.d_lat
    and b.longitude between p_lng - box.d_lng and p_lng + box.d_lng
    and b.status <> 'rejected'
  having 2 * 6371000 * asin(
           sqrt(
             power(sin(radians(b.latitude - p_lat) / 2), 2) +
             cos(radians(p_lat)) * cos(radians(b.latitude)) *
             power(sin(radians(b.longitude - p_lng) / 2), 2)
           )
         ) <= p_radius_m
  order by distance_m
  limit 5;
$$;

grant execute on function public.bidets_near(double precision, double precision, double precision)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. Read your own rating back
-- ---------------------------------------------------------------------------

-- bidet_ratings had no select policy at all, so the app could write a rating
-- and never read it — which is why the rating sheet always opened blank even
-- though submit_bidet_rating() upserts.
drop policy if exists ratings_select_all on public.bidet_ratings;
create policy ratings_select_own_or_admin on public.bidet_ratings
  for select using (user_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- 8. Moderation helpers
-- ---------------------------------------------------------------------------

create or replace function public.reject_bidet(
  p_bidet_id uuid,
  p_reason   text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only a moderator can reject a submission.'
      using errcode = '42501';
  end if;

  update public.bidets
  set status           = 'rejected',
      rejection_reason = nullif(trim(p_reason), ''),
      reviewed_by      = auth.uid(),
      reviewed_at      = now()
  where id = p_bidet_id;
end;
$$;

grant execute on function public.reject_bidet(uuid, text) to authenticated;

create or replace function public.approve_bidet(p_bidet_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only a moderator can approve a submission.'
      using errcode = '42501';
  end if;

  update public.bidets
  set status           = 'approved',
      rejection_reason = null,
      reviewed_by      = auth.uid(),
      reviewed_at      = now()
  where id = p_bidet_id;
end;
$$;

grant execute on function public.approve_bidet(uuid) to authenticated;
