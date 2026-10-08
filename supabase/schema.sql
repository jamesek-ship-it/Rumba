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
