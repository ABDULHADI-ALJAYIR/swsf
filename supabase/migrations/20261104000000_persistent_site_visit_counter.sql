create table if not exists public.site_visit_counter (
  id smallint primary key check (id = 1),
  total_visits bigint not null check (total_visits >= 1333),
  updated_at timestamptz not null default now()
);

create table if not exists public.site_visit_events (
  event_id uuid primary key,
  visited_at timestamptz not null default now()
);

alter table public.site_visit_counter enable row level security;
alter table public.site_visit_events enable row level security;

revoke all on table public.site_visit_counter from anon, authenticated;
revoke all on table public.site_visit_events from anon, authenticated;

insert into public.site_visit_counter (id, total_visits)
values (1, 1333)
on conflict (id) do nothing;

create or replace function public.register_site_visit(p_event_id uuid)
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  inserted_rows integer;
  current_total bigint;
begin
  if p_event_id is null then
    raise exception 'event_id is required';
  end if;

  insert into public.site_visit_events (event_id)
  values (p_event_id)
  on conflict (event_id) do nothing;

  get diagnostics inserted_rows = row_count;

  if inserted_rows = 1 then
    update public.site_visit_counter
       set total_visits = total_visits + 1,
           updated_at = now()
     where id = 1
     returning total_visits into current_total;
  else
    select total_visits into current_total
      from public.site_visit_counter
     where id = 1;
  end if;

  return current_total;
end;
$$;

create or replace function public.get_site_visit_count()
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select total_visits
    from public.site_visit_counter
   where id = 1;
$$;

revoke all on function public.register_site_visit(uuid) from public;
revoke all on function public.get_site_visit_count() from public;
grant execute on function public.register_site_visit(uuid) to anon, authenticated;
grant execute on function public.get_site_visit_count() to anon, authenticated;
