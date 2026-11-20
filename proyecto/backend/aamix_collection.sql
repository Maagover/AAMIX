-- AAMIX 0.9.0. Additive; no Auth/SMTP configuration changes.
create schema aamix_private;
revoke all on schema aamix_private from public, anon, authenticated;
grant usage on schema aamix_private to authenticated;
create table aamix_private.catalog_codes (code text primary key);
create table aamix_private.base_decks (
  id text primary key, name text not null, cover text not null,
  cards jsonb not null check (jsonb_typeof(cards) = 'array')
);
alter table aamix_private.catalog_codes enable row level security;
alter table aamix_private.base_decks enable row level security;
revoke all on all tables in schema aamix_private from public, anon, authenticated;
insert into aamix_private.catalog_codes(code) values ('0100'),('0101'),('0102'),('0103'),('0104'),('0105'),('0106'),('0107'),('0108'),('0109'),('0110'),('0111'),('0112'),('0113'),('0114'),('0115'),('0116'),('0117'),('0118'),('0119'),('0120'),('0121'),('0122'),('0123'),('0124'),('0125'),('0126'),('0127'),('0128'),('0129'),('0130'),('0131'),('0132'),('0133'),('0134'),('01a'),('01b'),('01c'),('01d'),('01e'),('01f');
insert into aamix_private.base_decks(id,name,cover,cards) values
('kajido','Mazo Kajido','0105','[{"codigo": "0105", "cantidad": 1}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0110", "cantidad": 3}, {"codigo": "0111", "cantidad": 2}, {"codigo": "0102", "cantidad": 2}, {"codigo": "0134", "cantidad": 1}, {"codigo": "0108", "cantidad": 1}, {"codigo": "0117", "cantidad": 1}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 3}, {"codigo": "0123", "cantidad": 3}, {"codigo": "0100", "cantidad": 18}]'::jsonb),
('papito','Mazo Papito','0115','[{"codigo": "0106", "cantidad": 3}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0108", "cantidad": 3}, {"codigo": "0111", "cantidad": 3}, {"codigo": "0115", "cantidad": 1}, {"codigo": "0116", "cantidad": 3}, {"codigo": "0120", "cantidad": 3}, {"codigo": "0117", "cantidad": 1}, {"codigo": "0133", "cantidad": 1}, {"codigo": "0119", "cantidad": 1}, {"codigo": "0100", "cantidad": 18}]'::jsonb),
('flaan','Mazo Flaan','0103','[{"codigo": "0103", "cantidad": 1}, {"codigo": "0112", "cantidad": 3}, {"codigo": "0113", "cantidad": 3}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0114", "cantidad": 3}, {"codigo": "0108", "cantidad": 2}, {"codigo": "0102", "cantidad": 1}, {"codigo": "0130", "cantidad": 1}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 3}, {"codigo": "0100", "cantidad": 18}]'::jsonb);

create table public.aamix_collection (
  user_id uuid not null references auth.users(id) on delete cascade,
  code text not null references aamix_private.catalog_codes(code),
  quantity integer not null check (quantity > 0),
  primary key (user_id, code)
);
create table public.aamix_owned_decks (
  user_id uuid not null references auth.users(id) on delete cascade,
  deck_id text not null references aamix_private.base_decks(id),
  name text not null, cover text not null, cards jsonb not null,
  obtained_at timestamptz not null default now(),
  primary key (user_id, deck_id)
);
create index aamix_owned_decks_template_idx on public.aamix_owned_decks(deck_id);
create index aamix_collection_code_idx on public.aamix_collection(code);
create table public.aamix_starter_gifts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  deck_id text not null references aamix_private.base_decks(id),
  awarded_at timestamptz not null default now()
);
create index aamix_starter_gifts_template_idx on public.aamix_starter_gifts(deck_id);
alter table public.aamix_collection enable row level security;
alter table public.aamix_owned_decks enable row level security;
alter table public.aamix_starter_gifts enable row level security;
revoke all on public.aamix_collection, public.aamix_owned_decks, public.aamix_starter_gifts from public, anon, authenticated;
grant select on public.aamix_collection, public.aamix_owned_decks, public.aamix_starter_gifts to authenticated;
create policy collection_owner_read on public.aamix_collection for select to authenticated using ((select auth.uid()) = user_id);
create policy decks_owner_read on public.aamix_owned_decks for select to authenticated using ((select auth.uid()) = user_id);
create policy gift_owner_read on public.aamix_starter_gifts for select to authenticated using ((select auth.uid()) = user_id);

create function public.aamix_inventory() returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  return jsonb_build_object(
    'user_id', uid,
    'gift', (select jsonb_build_object('deck_id',deck_id,'awarded_at',awarded_at) from public.aamix_starter_gifts where user_id = uid),
    'collection', coalesce((select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id = uid),'{}'::jsonb),
    'decks', coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id = uid),'[]'::jsonb)
  );
end $$;
revoke all on function public.aamix_inventory() from public, anon, authenticated;
grant execute on function public.aamix_inventory() to authenticated;

-- Only this private function can grant cards. No owner/quantities supplied by client.
create function aamix_private.claim_starter(p_deck_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  chosen aamix_private.base_decks%rowtype;
  granted uuid;
  result jsonb;
begin
  if uid is null or not exists (select 1 from auth.users u where u.id = uid and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)) then
    raise exception 'Confirmed email account required' using errcode = '28000';
  end if;
  select * into chosen from aamix_private.base_decks where id = p_deck_id;
  if not found then raise exception 'Unknown base deck' using errcode = '22023'; end if;
  -- Unique UUID is the concurrency gate. A conflicting request waits for commit.
  insert into public.aamix_starter_gifts(user_id,deck_id) values (uid,chosen.id)
    on conflict (user_id) do nothing returning user_id into granted;
  if granted is not null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',(e->>'cantidad')::integer from jsonb_array_elements(chosen.cards) e
      on conflict (user_id,code) do update set quantity = public.aamix_collection.quantity + excluded.quantity;
    insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
      values (uid,chosen.id,chosen.name,chosen.cover,chosen.cards);
  end if;
  result := public.aamix_inventory();
  return result || jsonb_build_object('already_claimed',granted is null);
end $$;
revoke all on function aamix_private.claim_starter(text) from public, anon, authenticated;
grant execute on function aamix_private.claim_starter(text) to authenticated;
create function public.aamix_claim_starter(p_deck_id text) returns jsonb
language sql security invoker set search_path = '' as $$
  select aamix_private.claim_starter(p_deck_id);
$$;
revoke all on function public.aamix_claim_starter(text) from public, anon, authenticated;
grant execute on function public.aamix_claim_starter(text) to authenticated;
notify pgrst, 'reload schema';
