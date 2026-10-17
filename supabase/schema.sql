-- LocalLift CRM shared storage.
-- The page never touches the tables directly: it calls crm_pull / crm_push with the team passcode,
-- and those functions check it against a bcrypt hash before reading or writing.
create extension if not exists pgcrypto with schema extensions;

-- one row per lead state ("s:<lead id>") or per hand-added lead ("c:<lead id>"); d is the JSON text as the page wrote it
create table if not exists public.crm_items (
  k text primary key,
  d text,
  del boolean not null default false,
  by text,
  updated_at timestamptz not null default clock_timestamp()
);
create index if not exists crm_items_updated_at on public.crm_items (updated_at);

create table if not exists public.crm_secret (
  id int primary key default 1 check (id = 1),
  hash text not null
);

alter table public.crm_items enable row level security;
alter table public.crm_secret enable row level security;
revoke all on public.crm_items, public.crm_secret from anon, authenticated;

create or replace function public.crm_ok(p_pass text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from crm_secret where hash = crypt(p_pass, hash));
$$;
revoke all on function public.crm_ok(text) from public, anon, authenticated;

-- rows changed since p_since (all rows when null); 10 s overlap so a write committing during the last pull isn't missed
create or replace function public.crm_pull(p_pass text, p_since timestamptz default null) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_now timestamptz := clock_timestamp();
begin
  if not crm_ok(p_pass) then raise exception 'bad passcode'; end if;
  return jsonb_build_object('now', v_now, 'rows', coalesce((
    select jsonb_agg(jsonb_build_object('k', k, 'd', d, 'del', del, 'by', by))
    from crm_items where p_since is null or updated_at > p_since - interval '10 seconds'), '[]'::jsonb));
end $$;

create or replace function public.crm_push(p_pass text, p_items jsonb, p_by text default null) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not crm_ok(p_pass) then raise exception 'bad passcode'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 2000 then raise exception 'bad items'; end if;
  insert into crm_items (k, d, del, by, updated_at)
  select x->>'k', x->>'d', coalesce((x->>'del')::boolean, false), left(p_by, 60), clock_timestamp()
  from jsonb_array_elements(p_items) x
  where x->>'k' ~ '^[sc]:[A-Za-z0-9_-]{1,80}$' and coalesce(length(x->>'d'), 0) < 200000
  on conflict (k) do update set d = excluded.d, del = excluded.del, by = excluded.by, updated_at = excluded.updated_at;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.crm_pull(text, timestamptz), public.crm_push(text, jsonb, text) from public;
grant execute on function public.crm_pull(text, timestamptz), public.crm_push(text, jsonb, text) to anon, authenticated;

-- set or change the team passcode (run once, by hand, in the SQL editor):
-- insert into public.crm_secret (id, hash) values (1, extensions.crypt('<passcode>', extensions.gen_salt('bf')))
--   on conflict (id) do update set hash = excluded.hash;
