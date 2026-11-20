-- AAMIX 0.10.0 rewards. Additive extension of the already applied 0.9.0 backend.
-- No Auth/SMTP settings, existing accounts, sessions or existing awards are changed.
-- Daily mission: once per UUID per calendar day in America/Santiago.
-- IMPORTANT: local AI completion is client-reported, not authoritative gameplay proof.
-- This file is a build template. Apply aamix_rewards.sql, never this template.
-- HISTORICAL 0.10.0: its original draw includes promotional normal cards.
-- Current 0.10.1 rules require aamix_no_promo_packs.sql AFTER the original migration.
-- Do not replay the original migration on an existing installation; this template
-- does not include or deploy the additive promotional-card correction.

create table aamix_private.reward_catalog (
  code text primary key references aamix_private.catalog_codes(code),
  name text not null,
  card_class text not null,
  special_weight integer not null check (special_weight between 0 and 100),
  check (card_class <> 'Recurso' or special_weight = 0)
);
alter table aamix_private.reward_catalog enable row level security;
revoke all on aamix_private.reward_catalog from public, anon, authenticated;
-- CATALOGUE_AND_MAAGO_SEED

create table public.aamix_rewards_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  avatar_code text references aamix_private.reward_catalog(code),
  packs integer not null default 0 check (packs >= 0)
);
create index aamix_rewards_avatar_idx on public.aamix_rewards_state(avatar_code);
create table public.aamix_code_redemptions (
  user_id uuid not null references auth.users(id) on delete cascade,
  gift_code text not null,
  redeemed_at timestamptz not null default now(),
  primary key (user_id, gift_code)
);
create table public.aamix_match_receipts (
  match_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  deck_id text not null references aamix_private.base_decks(id),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  result text check (result in ('victory','defeat')),
  unique (user_id,request_id),
  check ((finished_at is null) = (result is null))
);
create index aamix_match_deck_idx on public.aamix_match_receipts(deck_id);
create table public.aamix_daily_missions (
  user_id uuid not null references auth.users(id) on delete cascade,
  mission_day date not null,
  completed_match_id uuid not null references public.aamix_match_receipts(match_id),
  completed_at timestamptz not null default now(),
  claimed_at timestamptz,
  primary key (user_id,mission_day)
);
create index aamix_daily_match_idx on public.aamix_daily_missions(completed_match_id);
create table public.aamix_pack_openings (
  opening_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  cards jsonb not null check (jsonb_typeof(cards) = 'array' and jsonb_array_length(cards) = 5),
  opened_at timestamptz not null default now(),
  revealed_at timestamptz,
  unique (user_id,request_id)
);
create unique index aamix_one_pending_opening_idx on public.aamix_pack_openings(user_id) where revealed_at is null;
-- Every retry UUID is mapped, including a second client resuming an existing opening.
-- Otherwise that second UUID could consume another pack after the opening was acknowledged.
create table public.aamix_pack_requests (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  opening_id uuid not null references public.aamix_pack_openings(opening_id) on delete cascade,
  primary key(user_id,request_id)
);
create index aamix_pack_request_opening_idx on public.aamix_pack_requests(opening_id);

alter table public.aamix_rewards_state enable row level security;
alter table public.aamix_code_redemptions enable row level security;
alter table public.aamix_match_receipts enable row level security;
alter table public.aamix_daily_missions enable row level security;
alter table public.aamix_pack_openings enable row level security;
alter table public.aamix_pack_requests enable row level security;
revoke all on public.aamix_rewards_state, public.aamix_code_redemptions, public.aamix_match_receipts, public.aamix_daily_missions, public.aamix_pack_openings, public.aamix_pack_requests from public, anon, authenticated;
grant select on public.aamix_rewards_state, public.aamix_code_redemptions, public.aamix_match_receipts, public.aamix_daily_missions, public.aamix_pack_openings, public.aamix_pack_requests to authenticated;
create policy rewards_owner_read on public.aamix_rewards_state for select to authenticated using ((select auth.uid()) = user_id);
create policy redemptions_owner_read on public.aamix_code_redemptions for select to authenticated using ((select auth.uid()) = user_id);
create policy matches_owner_read on public.aamix_match_receipts for select to authenticated using ((select auth.uid()) = user_id);
create policy missions_owner_read on public.aamix_daily_missions for select to authenticated using ((select auth.uid()) = user_id);
create policy openings_owner_read on public.aamix_pack_openings for select to authenticated using ((select auth.uid()) = user_id);
create policy pack_requests_owner_read on public.aamix_pack_requests for select to authenticated using ((select auth.uid()) = user_id);

create or replace function public.aamix_inventory() returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare uid uuid := auth.uid(); today date := (now() at time zone 'America/Santiago')::date;
begin
  if uid is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  return jsonb_build_object(
    'user_id',uid,
    'gift',(select jsonb_build_object('deck_id',deck_id,'awarded_at',awarded_at) from public.aamix_starter_gifts where user_id=uid),
    'collection',coalesce((select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=uid),'{}'::jsonb),
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',jsonb_build_object('id','play_one','title','Juega 1 partida','day',today,'timezone','America/Santiago','progress',case when exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today) then 1 else 0 end,'target',1,'claimed',exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today and claimed_at is not null),'reward_packs',1),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'cards',cards,'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb)
  );
end $$;
revoke all on function public.aamix_inventory() from public, anon, authenticated;
grant execute on function public.aamix_inventory() to authenticated;

-- Internal identity guard. No public grant: clients cannot choose another UUID.
create function aamix_private.reward_user() returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null or not exists(select 1 from auth.users u where u.id=uid and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)) then
    raise exception 'Confirmed email account required' using errcode='28000';
  end if;
  return uid;
end $$;
revoke all on function aamix_private.reward_user() from public, anon, authenticated;

-- Internal serialization gate: all rewards and opening requests for a UUID lock this row.
create function aamix_private.lock_rewards() returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.reward_user();
begin
  insert into public.aamix_rewards_state(user_id) values(uid) on conflict(user_id) do nothing;
  perform 1 from public.aamix_rewards_state where user_id=uid for update;
  return uid;
end $$;
revoke all on function aamix_private.lock_rewards() from public, anon, authenticated;

-- Only three decks are eligible for the original starter reward.
-- This keeps the new Maago template out of the starter RPC without touching prior awards.
create or replace function aamix_private.claim_starter(p_deck_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.reward_user(); chosen aamix_private.base_decks%rowtype; granted uuid;
begin
  if p_deck_id is null or p_deck_id not in ('kajido','flaan','papito') then raise exception 'Unknown base deck' using errcode='22023'; end if;
  select * into strict chosen from aamix_private.base_decks where id=p_deck_id;
  insert into public.aamix_starter_gifts(user_id,deck_id) values(uid,chosen.id) on conflict(user_id) do nothing returning user_id into granted;
  if granted is not null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',(e->>'cantidad')::integer from jsonb_array_elements(chosen.cards) e order by e->>'codigo'
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards) values(uid,chosen.id,chosen.name,chosen.cover,chosen.cards);
  end if;
  return public.aamix_inventory() || jsonb_build_object('already_claimed',granted is null);
end $$;
revoke all on function aamix_private.claim_starter(text) from public, anon, authenticated;
grant execute on function aamix_private.claim_starter(text) to authenticated;

create function aamix_private.set_avatar(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.lock_rewards();
begin
  if not exists(select 1 from aamix_private.reward_catalog where code=p_code and card_class='Aliado') then raise exception 'AAMIX_INVALID_AVATAR' using errcode='22023'; end if;
  update public.aamix_rewards_state set avatar_code=p_code where user_id=uid;
  return public.aamix_inventory();
end $$;

create function aamix_private.redeem_code(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.lock_rewards(); normalized text := upper(btrim(p_code)); granted uuid; chosen aamix_private.base_decks%rowtype;
begin
  if normalized is null or normalized <> 'M4Z0M44G0' then raise exception 'AAMIX_INVALID_CODE' using errcode='22023'; end if;
  select * into strict chosen from aamix_private.base_decks where id='maago';
  insert into public.aamix_code_redemptions(user_id,gift_code) values(uid,normalized) on conflict(user_id,gift_code) do nothing returning user_id into granted;
  if granted is not null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',(e->>'cantidad')::integer from jsonb_array_elements(chosen.cards) e order by e->>'codigo'
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards) values(uid,chosen.id,chosen.name,chosen.cover,chosen.cards) on conflict(user_id,deck_id) do nothing;
  end if;
  return public.aamix_inventory() || jsonb_build_object('already_redeemed',granted is null,'reward_deck_id','maago');
end $$;

create function aamix_private.begin_match(p_request_id uuid,p_deck_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  if not exists(select 1 from public.aamix_owned_decks where user_id=uid and deck_id=p_deck_id) then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found and receipt.deck_id <> p_deck_id then raise exception 'Request UUID already used for a different deck' using errcode='22023'; end if;
  if not found then
    insert into public.aamix_match_receipts(user_id,request_id,deck_id) values(uid,p_request_id,p_deck_id) returning * into receipt;
  end if;
  return public.aamix_inventory() || jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result);
end $$;

create function aamix_private.finish_match(p_match_id uuid,p_result text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype; today date := (now() at time zone 'America/Santiago')::date;
begin
  if p_result is null or p_result not in ('victory','defeat') then raise exception 'Completed victory or defeat required' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and match_id=p_match_id for update;
  if not found then raise exception 'Unknown match receipt' using errcode='22023'; end if;
  if receipt.result is null then
    update public.aamix_match_receipts set finished_at=now(),result=p_result where match_id=receipt.match_id;
    insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id) values(uid,today,receipt.match_id) on conflict(user_id,mission_day) do nothing;
  elsif receipt.result <> p_result then
    raise exception 'Match already finished with another result' using errcode='22023';
  end if;
  return public.aamix_inventory() || jsonb_build_object('match_id',receipt.match_id,'match_result',p_result);
end $$;

create function aamix_private.claim_daily_mission() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.lock_rewards(); today date := (now() at time zone 'America/Santiago')::date; daily public.aamix_daily_missions%rowtype; already boolean;
begin
  select * into daily from public.aamix_daily_missions where user_id=uid and mission_day=today for update;
  if not found then raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023'; end if;
  already := daily.claimed_at is not null;
  if not already then
    update public.aamix_daily_missions set claimed_at=now() where user_id=uid and mission_day=today;
    update public.aamix_rewards_state set packs=packs+1 where user_id=uid;
  end if;
  return public.aamix_inventory() || jsonb_build_object('already_claimed',already);
end $$;

-- Private draw helper. No client arguments, execution grant or externally exposed schema.
-- Slot1 one resource; slots2-4 normals with replacement; slot5 70%normal /30%special.
-- Within special group: four named cards5%each; five other cards16%each.
create function aamix_private.draw_pack() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare codes jsonb := '[]'::jsonb; selected text; ticket double precision; slot integer;
begin
  perform aamix_private.reward_user();
  select code into strict selected from aamix_private.reward_catalog where card_class='Recurso' order by random() limit 1;
  codes := codes || jsonb_build_array(selected);
  for slot in 2..5 loop
    if slot=5 and random()<0.30 then
      ticket := random()*100;
      select code into strict selected from (
        select code,sum(special_weight) over(order by code rows unbounded preceding) as cumulative
        from aamix_private.reward_catalog where special_weight>0
      ) weighted where cumulative>ticket order by cumulative limit 1;
    else
      select code into strict selected from aamix_private.reward_catalog where card_class<>'Recurso' and special_weight=0 order by random() limit 1;
    end if;
    codes := codes || jsonb_build_array(selected);
  end loop;
  return codes;
end $$;
revoke all on function aamix_private.draw_pack() from public, anon, authenticated;

create function aamix_private.open_pack(p_request_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.lock_rewards(); opening public.aamix_pack_openings%rowtype; inventory jsonb;
begin
  if p_request_id is null then raise exception 'Opening request UUID required' using errcode='22023'; end if;
  -- Retry of an acknowledged request still returns that exact old result.
  select o.* into opening from public.aamix_pack_requests r join public.aamix_pack_openings o on o.opening_id=r.opening_id where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
  if not found then
    -- Resume an unfinished animation, regardless of a new/restarted client's request UUID.
    select * into opening from public.aamix_pack_openings where user_id=uid and revealed_at is null;
    if not found then
      update public.aamix_rewards_state set packs=packs-1 where user_id=uid and packs>0;
      if not found then raise exception 'AAMIX_NO_PACKS' using errcode='22023'; end if;
      insert into public.aamix_pack_openings(user_id,request_id,cards) values(uid,p_request_id,aamix_private.draw_pack()) returning * into opening;
      insert into public.aamix_collection(user_id,code,quantity)
        select uid,code,count(*)::integer from jsonb_array_elements_text(opening.cards) as card(code) group by code order by code
        on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    end if;
  end if;
  insert into public.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict(user_id,request_id) do nothing;
  inventory := public.aamix_inventory();
  return inventory || jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'cards',opening.cards,'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end $$;

create function aamix_private.acknowledge_opening(p_opening_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := aamix_private.lock_rewards();
begin
  update public.aamix_pack_openings set revealed_at=coalesce(revealed_at,now()) where user_id=uid and opening_id=p_opening_id;
  if not found then raise exception 'Unknown pack opening' using errcode='22023'; end if;
  return public.aamix_inventory();
end $$;

-- Public API contains only invoker wrappers; private entry points check live confirmed UID.
create function public.aamix_set_avatar(p_code text) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.set_avatar(p_code); $$;
create function public.aamix_redeem_code(p_code text) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.redeem_code(p_code); $$;
create function public.aamix_begin_match(p_request_id uuid,p_deck_id text) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.begin_match(p_request_id,p_deck_id); $$;
create function public.aamix_finish_match(p_match_id uuid,p_result text) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.finish_match(p_match_id,p_result); $$;
create function public.aamix_claim_daily_mission() returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.claim_daily_mission(); $$;
create function public.aamix_open_pack(p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.open_pack(p_request_id); $$;
create function public.aamix_acknowledge_opening(p_opening_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.acknowledge_opening(p_opening_id); $$;

revoke all on function aamix_private.set_avatar(text),aamix_private.redeem_code(text),aamix_private.begin_match(uuid,text),aamix_private.finish_match(uuid,text),aamix_private.claim_daily_mission(),aamix_private.open_pack(uuid),aamix_private.acknowledge_opening(uuid) from public,anon,authenticated;
grant execute on function aamix_private.set_avatar(text),aamix_private.redeem_code(text),aamix_private.begin_match(uuid,text),aamix_private.finish_match(uuid,text),aamix_private.claim_daily_mission(),aamix_private.open_pack(uuid),aamix_private.acknowledge_opening(uuid) to authenticated;
revoke all on function public.aamix_set_avatar(text),public.aamix_redeem_code(text),public.aamix_begin_match(uuid,text),public.aamix_finish_match(uuid,text),public.aamix_claim_daily_mission(),public.aamix_open_pack(uuid),public.aamix_acknowledge_opening(uuid) from public,anon,authenticated;
grant execute on function public.aamix_set_avatar(text),public.aamix_redeem_code(text),public.aamix_begin_match(uuid,text),public.aamix_finish_match(uuid,text),public.aamix_claim_daily_mission(),public.aamix_open_pack(uuid),public.aamix_acknowledge_opening(uuid) to authenticated;
notify pgrst,'reload schema';
