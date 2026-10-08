-- Rumbo Español: conversation coach daily message caps. Run in the Supabase SQL editor.
-- Safe to run more than once (it replaces the earlier version of the counter function).

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
