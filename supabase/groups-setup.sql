-- Duck Tracker: accounts + hunting groups
-- Run once in Supabase → SQL Editor → New query → Run. Safe to re-run.

-- 1. Tables ------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40)
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  join_code text not null unique,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists group_members_user on public.group_members (user_id);

create table if not exists public.hunt_log (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  data jsonb not null,
  updated_at timestamptz not null default now()
);
create index if not exists hunt_log_user on public.hunt_log (user_id);

-- 2. Helpers (security definer so policies don't recurse) ---------------
create or replace function public.my_group_ids() returns setof uuid
language sql stable security definer set search_path = public as $$
  select group_id from group_members where user_id = auth.uid()
$$;

create or replace function public.is_group_mate(other uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from group_members a join group_members b on a.group_id = b.group_id
    where a.user_id = auth.uid() and b.user_id = other)
$$;

-- 3. Row-level security -------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.groups        enable row level security;
alter table public.group_members enable row level security;
alter table public.hunt_log      enable row level security;

drop policy if exists "profiles read"   on public.profiles;
drop policy if exists "profiles insert" on public.profiles;
drop policy if exists "profiles update" on public.profiles;
create policy "profiles read"   on public.profiles for select to authenticated using (id = auth.uid() or public.is_group_mate(id));
create policy "profiles insert" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "groups read" on public.groups;
create policy "groups read" on public.groups for select to authenticated using (id in (select public.my_group_ids()));

drop policy if exists "members read"  on public.group_members;
drop policy if exists "members leave" on public.group_members;
create policy "members read"  on public.group_members for select to authenticated using (group_id in (select public.my_group_ids()));
create policy "members leave" on public.group_members for delete to authenticated using (user_id = auth.uid());

drop policy if exists "hunts read"   on public.hunt_log;
drop policy if exists "hunts insert" on public.hunt_log;
drop policy if exists "hunts update" on public.hunt_log;
drop policy if exists "hunts delete" on public.hunt_log;
create policy "hunts read"   on public.hunt_log for select to authenticated using (user_id = auth.uid() or public.is_group_mate(user_id));
create policy "hunts insert" on public.hunt_log for insert to authenticated with check (user_id = auth.uid());
create policy "hunts update" on public.hunt_log for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "hunts delete" on public.hunt_log for delete to authenticated using (user_id = auth.uid());

-- 4. Create / join a group by code -------------------------------------
create or replace function public.create_group(p_name text) returns json
language plpgsql security definer set search_path = public as $$
declare g groups; code text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  loop
    code := upper(substr(translate(md5(random()::text || clock_timestamp()::text), '01', ''), 1, 6));
    exit when length(code) = 6 and not exists (select 1 from groups where join_code = code);
  end loop;
  insert into groups (name, join_code, created_by) values (trim(p_name), code, auth.uid()) returning * into g;
  insert into group_members (group_id, user_id) values (g.id, auth.uid());
  return json_build_object('id', g.id, 'name', g.name, 'join_code', g.join_code);
end $$;

create or replace function public.join_group(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare g groups;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into g from groups where join_code = upper(trim(p_code));
  if not found then raise exception 'group not found'; end if;
  insert into group_members (group_id, user_id) values (g.id, auth.uid()) on conflict do nothing;
  return json_build_object('id', g.id, 'name', g.name, 'join_code', g.join_code);
end $$;

revoke execute on function public.create_group(text), public.join_group(text), public.my_group_ids(), public.is_group_mate(uuid) from public, anon;
grant  execute on function public.create_group(text), public.join_group(text), public.my_group_ids(), public.is_group_mate(uuid) to authenticated;

-- 5. Lock down the old crew-code table (it let anyone with the key read/write).
--    Hunts re-upload from each phone after sign-in, so nothing is lost.
do $$ begin
  if to_regclass('public.hunts') is not null then
    drop policy if exists "crew read"   on public.hunts;
    drop policy if exists "crew insert" on public.hunts;
    drop policy if exists "crew update" on public.hunts;
    drop policy if exists "crew delete" on public.hunts;
  end if;
end $$;
