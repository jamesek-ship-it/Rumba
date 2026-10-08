-- Rumbo Español: run this once in the Supabase SQL editor.

-- One row of progress per signed-in person.
create table if not exists public.rumbo_progress (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  state      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.rumbo_progress enable row level security;

-- Each person can read and write only their own row.
create policy "read own progress" on public.rumbo_progress
  for select to authenticated using (auth.uid() = user_id);

create policy "insert own progress" on public.rumbo_progress
  for insert to authenticated with check (auth.uid() = user_id);

create policy "update own progress" on public.rumbo_progress
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "delete own progress" on public.rumbo_progress
  for delete to authenticated using (auth.uid() = user_id);

-- Lets the "Delete my account" button remove the signed-in person's account
-- (their progress row goes with it through the foreign key).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- ---------------------------------------------------------------------------
-- Group leaderboard ("Los muchachos"). Safe to run on its own if you already ran the part above.
-- A group is just an 8-character code in the invite link. Members can see the other members who
-- share a code with them, and nobody else's rows.
-- ---------------------------------------------------------------------------
create table if not exists public.rumbo_group_members (
  group_code   text not null check (group_code ~ '^[A-Z0-9]{8}$'),
  user_id      uuid not null references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 24),
  learned      int  not null default 0 check (learned between 0 and 1000),
  streak       int  not null default 0 check (streak >= 0),
  week_days    int  not null default 0 check (week_days between 0 and 7),
  updated_at   timestamptz not null default now(),
  primary key (group_code, user_id)
);

alter table public.rumbo_group_members enable row level security;

-- Returns the group codes the signed-in person belongs to. It runs with the owner's rights so the
-- select policy below can use it without recursing into itself.
create or replace function public.my_group_codes()
returns setof text
language sql
security definer
stable
set search_path = public
as $$
  select group_code from public.rumbo_group_members where user_id = auth.uid();
$$;

revoke all on function public.my_group_codes() from public, anon;
grant execute on function public.my_group_codes() to authenticated;

drop policy if exists "see my group" on public.rumbo_group_members;
create policy "see my group" on public.rumbo_group_members
  for select to authenticated using (group_code in (select public.my_group_codes()));

drop policy if exists "join as myself" on public.rumbo_group_members;
create policy "join as myself" on public.rumbo_group_members
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "update my row" on public.rumbo_group_members;
create policy "update my row" on public.rumbo_group_members
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "leave my group" on public.rumbo_group_members;
create policy "leave my group" on public.rumbo_group_members
  for delete to authenticated using (auth.uid() = user_id);


-- ---------------------------------------------------------------------------
-- Conversation coach: daily message cap. Safe to run on its own.
-- Only the Edge Function (service role) can touch these; the app never reads them directly.
-- ---------------------------------------------------------------------------
create table if not exists public.rumbo_chat_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day     date not null,
  count   int  not null default 0,
  primary key (user_id, day)
);
alter table public.rumbo_chat_usage enable row level security;   -- no policies: nobody but the service role

-- Adds one to today's count (day boundary = Eastern time). Returns the new count,
-- -1 if this person reached their daily limit, or -3 if everyone together reached the group-wide limit.
drop function if exists public.rumbo_chat_bump(uuid, int);
create or replace function public.rumbo_chat_bump(p_user uuid, p_limit int, p_global int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  d date := (now() at time zone 'America/Detroit')::date;
  n int;
  total int;
begin
  select coalesce(sum(count), 0) into total from public.rumbo_chat_usage where day = d;
  if total >= p_global then return -3; end if;
  insert into public.rumbo_chat_usage (user_id, day, count)
  values (p_user, d, 1)
  on conflict (user_id, day) do update set count = public.rumbo_chat_usage.count + 1
    where public.rumbo_chat_usage.count < p_limit
  returning count into n;
  return coalesce(n, -1);
end;
$$;

create or replace function public.rumbo_chat_refund(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.rumbo_chat_usage set count = greatest(count - 1, 0)
  where user_id = p_user and day = (now() at time zone 'America/Detroit')::date;
$$;

revoke all on function public.rumbo_chat_bump(uuid, int, int) from public, anon, authenticated;
revoke all on function public.rumbo_chat_refund(uuid) from public, anon, authenticated;
grant execute on function public.rumbo_chat_bump(uuid, int, int) to service_role;
grant execute on function public.rumbo_chat_refund(uuid) to service_role;
