-- AAMIX 1.1: custom decks. Additive; no account, inventory, wallet, reward or pack reset.
-- Base/gift definitions remain immutable and inventory.decks stays compatible with v1.0.
-- All new writes use authenticated server functions; user_id never comes from clients.

alter table aamix_private.reward_catalog add column is_singular boolean not null default false;
-- Derived from catalogo_edicion_1.json palabras_clave, including promotional Singular cards.
update aamix_private.reward_catalog set is_singular=true where code in('0103','0105','0115','0119','01c','01e','01f');

create table aamix_private.deck_registry(id text primary key);
insert into aamix_private.deck_registry(id) select id from aamix_private.base_decks;
alter table aamix_private.deck_registry enable row level security;
revoke all on aamix_private.deck_registry from public,anon,authenticated;

create table public.aamix_custom_decks(
  user_id uuid not null references auth.users(id) on delete cascade,
  deck_id text not null references aamix_private.deck_registry(id),
  name text not null check(char_length(name) between 1 and 48 and name !~ '[[:cntrl:]]'),
  cover text not null check(cover in('custom_transmision','custom_restos')),
  cards jsonb not null check(jsonb_typeof(cards)='array' and jsonb_array_length(cards)<=64),
  draft boolean not null default true,
  revision integer not null default 1 check(revision>0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(user_id,deck_id),
  unique(deck_id),
  check(deck_id ~ '^custom_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
);
alter table public.aamix_custom_decks enable row level security;
revoke all on public.aamix_custom_decks from public,anon,authenticated;
grant select on public.aamix_custom_decks to authenticated;
create policy custom_decks_owner_read on public.aamix_custom_decks for select to authenticated using((select auth.uid())=user_id);

create table aamix_private.custom_deck_requests(
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  payload jsonb not null,
  saved_deck jsonb not null,
  created_at timestamptz not null default now(),
  primary key(user_id,request_id)
);
alter table aamix_private.custom_deck_requests enable row level security;
revoke all on aamix_private.custom_deck_requests from public,anon,authenticated;

-- Preserve foreign-key integrity for historical base receipts and new custom receipts.
-- The new registry contains all existing base IDs before changing the FK.
alter table public.aamix_match_receipts drop constraint aamix_match_receipts_deck_id_fkey;
alter table public.aamix_match_receipts add constraint aamix_match_receipts_deck_id_fkey
  foreign key(deck_id) references aamix_private.deck_registry(id);
alter table public.aamix_match_receipts add column player_deck jsonb;
alter table public.aamix_match_receipts add constraint aamix_player_deck_shape
  check(player_deck is null or coalesce(jsonb_typeof(player_deck)='object' and player_deck->>'id'=deck_id and jsonb_typeof(player_deck->'cartas')='array',false));

create function aamix_private.custom_cards(p_uid uuid,p_cards jsonb,p_draft boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare e jsonb; code_value text; amount integer; owned integer; c aamix_private.reward_catalog%rowtype;
  total integer:=0; resources integer:=0; seen text[]:='{}'; normalized jsonb:='[]';
begin
  if p_uid is distinct from auth.uid() or p_uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  if p_draft is null or p_cards is null or jsonb_typeof(p_cards)<>'array' then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
  if jsonb_array_length(p_cards)>64 or octet_length(p_cards::text)>8192 then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
  for e in select value from jsonb_array_elements(p_cards) loop
    if jsonb_typeof(e)<>'object' then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
    if (select count(*) from jsonb_object_keys(e))<>2 or not(e ? 'codigo' and e ? 'cantidad')
      or jsonb_typeof(e->'codigo')<>'string' or jsonb_typeof(e->'cantidad')<>'number'
      or coalesce(e->>'cantidad','')!~'^[1-9][0-9]?$' then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
    code_value:=e->>'codigo'; amount:=(e->>'cantidad')::integer;
    if code_value=any(seen) then raise exception 'AAMIX_DUPLICATE_DECK_CARD' using errcode='22023'; end if;
    seen:=array_append(seen,code_value);
    select * into c from aamix_private.reward_catalog where code=code_value;
    if not found then raise exception 'AAMIX_UNKNOWN_CARD' using errcode='22023'; end if;
    if c.card_class<>'Recurso' and amount>(case when c.is_singular then 1 else 3 end) then raise exception 'AAMIX_DECK_COPY_LIMIT' using errcode='22023'; end if;
    select quantity into owned from public.aamix_collection where user_id=p_uid and code=code_value;
    if amount>coalesce(owned,0) then raise exception 'AAMIX_DECK_UNOWNED_COPIES' using errcode='22023'; end if;
    total:=total+amount;
    if total>40 then raise exception 'AAMIX_DECK_TOO_LARGE' using errcode='22023'; end if;
    if code_value='0100' then resources:=amount; end if;
    normalized:=normalized||jsonb_build_array(jsonb_build_object('codigo',code_value,'cantidad',amount));
  end loop;
  -- Playability size rule is deliberately centralized here; drafts may be empty.
  if not p_draft and (total<>40) then raise exception 'AAMIX_DECK_SIZE' using errcode='22023'; end if;
  if not p_draft and resources<1 then raise exception 'AAMIX_DECK_INITIAL_RESOURCE' using errcode='22023'; end if;
  return coalesce((select jsonb_agg(sorted.card order by sorted.card->>'codigo') from jsonb_array_elements(normalized) as sorted(card)),'[]'::jsonb);
end $$;
revoke all on function aamix_private.custom_cards(uuid,jsonb,boolean) from public,anon,authenticated;

create function aamix_private.save_custom_deck(p_request_id uuid,p_deck_id text,p_nombre text,p_portada text,p_cartas jsonb,p_draft boolean,p_expected_revision integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); d public.aamix_custom_decks%rowtype;
  old_request aamix_private.custom_deck_requests%rowtype; payload jsonb; saved jsonb; canonical_cards jsonb;
  normalized_id text:=coalesce(p_deck_id,''); normalized_name text:=btrim(p_nombre);
begin
  if p_request_id is null or p_expected_revision is null or p_expected_revision<0 or p_draft is null
    or normalized_name is null or char_length(normalized_name) not between 1 and 48 or normalized_name ~ '[[:cntrl:]]'
    or p_portada is null or p_portada not in('custom_transmision','custom_restos')
    or p_cartas is null or octet_length(p_cartas::text)>8192 then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
  payload:=jsonb_build_object('id',normalized_id,'nombre',normalized_name,'portada',p_portada,'cartas',p_cartas,'draft',p_draft,'expected_revision',p_expected_revision);
  select * into old_request from aamix_private.custom_deck_requests where user_id=uid and request_id=p_request_id;
  if found then
    if old_request.payload<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return public.aamix_inventory()||jsonb_build_object('saved_deck',old_request.saved_deck,'last_saved_deck',old_request.saved_deck);
  end if;
  canonical_cards:=aamix_private.custom_cards(uid,p_cartas,p_draft);
  if normalized_id='' then
    if p_expected_revision<>0 then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001'; end if;
    normalized_id:='custom_'||gen_random_uuid()::text;
    insert into aamix_private.deck_registry(id) values(normalized_id);
    insert into public.aamix_custom_decks(user_id,deck_id,name,cover,cards,draft)
      values(uid,normalized_id,normalized_name,p_portada,canonical_cards,p_draft) returning * into d;
  else
    if normalized_id !~ '^custom_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'AAMIX_DECK_IMMUTABLE' using errcode='22023'; end if;
    select * into d from public.aamix_custom_decks where user_id=uid and deck_id=normalized_id for update;
    if not found then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
    if d.revision<>p_expected_revision then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001'; end if;
    update public.aamix_custom_decks set name=normalized_name,cover=p_portada,cards=canonical_cards,draft=p_draft,revision=revision+1,updated_at=now()
      where user_id=uid and deck_id=normalized_id returning * into d;
  end if;
  saved:=jsonb_build_object('id',d.deck_id,'nombre',d.name,'portada',d.cover,'recurso_inicial','0100','cartas',d.cards,'custom',true,'draft',d.draft,'revision',d.revision);
  insert into aamix_private.custom_deck_requests(user_id,request_id,payload,saved_deck) values(uid,p_request_id,payload,saved);
  return public.aamix_inventory()||jsonb_build_object('saved_deck',saved,'last_saved_deck',saved);
end $$;
revoke all on function aamix_private.save_custom_deck(uuid,text,text,text,jsonb,boolean,integer) from public,anon,authenticated;
grant execute on function aamix_private.save_custom_deck(uuid,text,text,text,jsonb,boolean,integer) to authenticated;
create function public.aamix_save_custom_deck(p_request_id uuid,p_deck_id text,p_nombre text,p_portada text,p_cartas jsonb,p_draft boolean,p_expected_revision integer) returns jsonb
language sql security invoker set search_path='' as $$
select aamix_private.save_custom_deck(p_request_id,p_deck_id,p_nombre,p_portada,p_cartas,p_draft,p_expected_revision);
$$;
revoke all on function public.aamix_save_custom_deck(uuid,text,text,text,jsonb,boolean,integer) from public,anon,authenticated;
grant execute on function public.aamix_save_custom_deck(uuid,text,text,text,jsonb,boolean,integer) to authenticated;

CREATE OR REPLACE FUNCTION public.aamix_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); missions jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  missions:=aamix_private.missions_status();
  return jsonb_build_object(
    'user_id',uid,'welcome_pack',aamix_private.welcome_status(),
    'restos_welcome_claimed',exists(select 1 from public.aamix_restos_welcome where user_id=uid),
    'restos',coalesce((select restos from public.aamix_rewards_state where user_id=uid),0),
    'normal_packs',coalesce((select normal_packs from public.aamix_rewards_state where user_id=uid),0),
    'shop',aamix_private.shop_catalog(),
    'gift',(select jsonb_build_object('deck_id',deck_id,'awarded_at',awarded_at) from public.aamix_starter_gifts where user_id=uid),
    'collection',coalesce((select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=uid),'{}'::jsonb),
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'custom_decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'custom',true,'draft',draft,'revision',revision) order by created_at,deck_id) from public.aamix_custom_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'kind',kind,'cards',cards,'new_card_indices',to_jsonb(new_card_indices),'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb));
end $function$;


-- All match creation resolves a single frozen copy; drafts never enter gameplay.
create or replace function aamix_private.mp_deck(p_uid uuid,p_deck_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d jsonb; custom_row public.aamix_custom_decks%rowtype;
begin
  if p_uid is null or p_uid is distinct from auth.uid() then raise exception 'Authentication required' using errcode='28000'; end if;
  select jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards)
    into d from public.aamix_owned_decks where user_id=p_uid and deck_id=p_deck_id;
  if d is not null then
    if (select coalesce(sum((e->>'cantidad')::integer),0) from jsonb_array_elements(d->'cartas')e)<>40 then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
    return d;
  end if;
  select * into custom_row from public.aamix_custom_decks where user_id=p_uid and deck_id=p_deck_id;
  if not found then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
  if custom_row.draft then raise exception 'AAMIX_DECK_DRAFT' using errcode='22023'; end if;
  perform aamix_private.custom_cards(p_uid,custom_row.cards,false);
  return jsonb_build_object('id',custom_row.deck_id,'nombre',custom_row.name,'portada',custom_row.cover,'recurso_inicial','0100','cartas',custom_row.cards,'custom',true,'draft',false,'revision',custom_row.revision);
end $$;
revoke all on function aamix_private.mp_deck(uuid,text) from public,anon,authenticated;

create or replace function aamix_private.begin_match(p_request_id uuid,p_deck_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype; d jsonb;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found then
    if receipt.deck_id<>p_deck_id or receipt.challenge_stage is not null or receipt.online_room_id is not null then raise exception 'Request UUID already used for a different match' using errcode='22023'; end if;
    d:=coalesce(receipt.player_deck,aamix_private.mp_deck(uid,p_deck_id));
  else
    d:=aamix_private.mp_deck(uid,p_deck_id);
    insert into public.aamix_match_receipts(user_id,request_id,deck_id,player_deck) values(uid,p_request_id,p_deck_id,d) returning * into receipt;
  end if;
  return public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result,'challenge_stage',null,'match_deck',d);
end $$;

create or replace function aamix_private.begin_challenge_match(p_request_id uuid,p_deck_id text,p_stage integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype;
  definition jsonb; opponent jsonb; d jsonb;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  select e into definition from jsonb_array_elements(aamix_private.challenge_definitions()) e where (e->>'stage')::integer=p_stage;
  if not found then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found then
    if receipt.deck_id<>p_deck_id or receipt.challenge_stage is distinct from p_stage then raise exception 'Request UUID already used for a different match' using errcode='22023'; end if;
    d:=coalesce(receipt.player_deck,aamix_private.mp_deck(uid,p_deck_id));
  else
    if exists(select 1 from generate_series(1,p_stage-1) previous(stage) where not exists(
      select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023'; end if;
    d:=aamix_private.mp_deck(uid,p_deck_id);
    select jsonb_build_object('id',id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) into strict opponent
      from aamix_private.base_decks where id=definition->>'deck_id';
    insert into public.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent,player_deck)
      values(uid,p_request_id,p_deck_id,p_stage,opponent,d) returning * into receipt;
  end if;
  return public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result,
    'challenge_stage',receipt.challenge_stage,'challenge_opponent',receipt.challenge_opponent,'match_deck',d);
end $$;

CREATE OR REPLACE FUNCTION aamix_private.mp_finish(p_room_id uuid, p_winner integer, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r aamix_private.mp_rooms%rowtype; u uuid; receipt uuid; s integer;
begin
  select * into strict r from aamix_private.mp_rooms where id=p_room_id for update;
  if r.status in('finished','cancelled') then return; end if;
  if r.started_at is null or p_winner not in(0,1) then
    update aamix_private.mp_rooms set status='cancelled',finished_at=now(),winner=-1,finish_reason=p_reason where id=r.id;
  else
    update aamix_private.mp_rooms set status='finished',finished_at=now(),winner=p_winner,finish_reason=p_reason where id=r.id;
    for s in 0..1 loop
      u:=case s when 0 then r.host_id else r.guest_id end;
      insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,online_room_id,player_deck)
        values(u,case s when 0 then r.host_receipt_request else r.guest_receipt_request end,
          case s when 0 then r.host_deck->>'id' else r.guest_deck->>'id' end,r.started_at,now(),
          case when s=p_winner then 'victory' else 'defeat' end,r.id,case s when 0 then r.host_deck else r.guest_deck end)
        on conflict(online_room_id,user_id) where online_room_id is not null do nothing returning match_id into receipt;
      if receipt is not null then
        insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id)
          values(u,(now() at time zone 'America/Santiago')::date,receipt) on conflict(user_id,mission_day) do nothing;
      end if;
    end loop;
  end if;
  delete from aamix_private.mp_members where room_id=r.id;
  update aamix_private.mp_commands set status='rejected' where room_id=r.id and status='pending';
end $function$;

notify pgrst,'reload schema';

