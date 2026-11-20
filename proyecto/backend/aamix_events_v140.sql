-- AAMIX 1.4. Additive calendar events; no resets or replay of historical migrations.
-- Only the server clock and the authenticated UUID determine availability/progress/rewards.
create table aamix_private.event_definitions(
 id text primary key, title text not null, card_code text not null,
 start_day date not null,end_day date not null,summary text not null,missions jsonb not null,
 check(end_day>=start_day),check(jsonb_typeof(missions)='array')
);
create table aamix_private.event_visits(
 user_id uuid not null references auth.users(id) on delete cascade,
 event_id text not null references aamix_private.event_definitions(id), day date not null,
 primary key(user_id,event_id,day)
);
create table aamix_private.event_claims(
 user_id uuid not null references auth.users(id) on delete cascade,
 event_id text not null references aamix_private.event_definitions(id),mission_id text not null,
 period_key text not null,reward jsonb not null,claimed_at timestamptz not null default now(),
 primary key(user_id,event_id,mission_id,period_key)
);
create table aamix_private.event_design_unlocks(
 user_id uuid not null references auth.users(id) on delete cascade,
 design text not null check(design='custom_kajido'),event_id text not null references aamix_private.event_definitions(id),
 unlocked_at timestamptz not null default now(),primary key(user_id,design)
);
alter table aamix_private.event_definitions enable row level security;
alter table aamix_private.event_visits enable row level security;
alter table aamix_private.event_claims enable row level security;
alter table aamix_private.event_design_unlocks enable row level security;
create policy events_server_only on aamix_private.event_definitions for all to anon,authenticated using(false) with check(false);
create policy event_visits_server_only on aamix_private.event_visits for all to anon,authenticated using(false) with check(false);
create policy event_claims_server_only on aamix_private.event_claims for all to anon,authenticated using(false) with check(false);
create policy event_designs_server_only on aamix_private.event_design_unlocks for all to anon,authenticated using(false) with check(false);
revoke all on aamix_private.event_definitions,aamix_private.event_visits,aamix_private.event_claims,aamix_private.event_design_unlocks from public,anon,authenticated;
create function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select statement_timestamp() $$;
revoke all on function aamix_private.event_clock() from public,anon,authenticated;
insert into aamix_private.event_definitions values('bienvenida_2026','Evento Bienvenida','0100','2026-10-21','2026-10-26','Celebramos la llegada de AAMIX Online. Durante este fin de semana, disfruta de 25 restos diarios y completa misiones para obtener recompensas.','[{"id": "login", "title": "Inicia sesión", "target": 1, "reward": {"restos": 25}, "metric": "login", "scope": "daily"}, {"id": "play_one", "title": "Juega 1 partida", "target": 1, "reward": {"restos": 25}, "metric": "played", "scope": "event"}, {"id": "win_one", "title": "Gana 1 partida", "target": 1, "reward": {"normal_packs": 1}, "metric": "wins", "scope": "event"}, {"id": "play_three", "title": "Juega 3 partidas", "target": 3, "reward": {"restos": 50}, "metric": "played", "scope": "event"}, {"id": "win_three", "title": "Gana 3 partidas", "target": 3, "reward": {"packs": 2}, "metric": "wins", "scope": "event"}]');
insert into aamix_private.event_definitions values('halloween_2026','Evento Halloween','0128','2026-10-30','2026-11-01','El terror se toma AAMIX, nuestras cartas más terroríficas están a la espera de que las colecciones','[{"id": "play_one", "title": "Juega 1 partida", "target": 1, "reward": {"restos": 10}, "metric": "played", "scope": "event"}, {"id": "win_one", "title": "Gana 1 partida", "target": 1, "reward": {"cards": [{"codigo": "0117", "cantidad": 1}]}, "metric": "wins", "scope": "event"}, {"id": "play_three", "title": "Juega 3 partidas", "target": 3, "reward": {"restos": 25}, "metric": "played", "scope": "event"}, {"id": "win_three", "title": "Gana 3 partidas", "target": 3, "reward": {"cards": [{"codigo": "0122", "cantidad": 1}]}, "metric": "wins", "scope": "event"}, {"id": "play_five", "title": "Juega 5 partidas", "target": 5, "reward": {"restos": 50}, "metric": "played", "scope": "event"}, {"id": "win_five", "title": "Gana 5 partidas", "target": 5, "reward": {"cards": [{"codigo": "0128", "cantidad": 1}]}, "metric": "wins", "scope": "event"}]');
insert into aamix_private.event_definitions values('javieriv_2026','Cumpleaños Javieriv','0104','2026-11-12','2026-11-14','Este 13/11 celebramos el cumpleaños de Javieriv. Completa las misiones para obtener cartas Javieriv de recompensa.','[{"id": "play_one", "title": "Juega 1 partida", "target": 1, "reward": {"restos": 25, "cards": [{"codigo": "0104", "cantidad": 1}]}, "metric": "played", "scope": "event"}, {"id": "win_one_javieriv", "title": "Gana 1 partida con un mazo que incluya al menos 1 Javieriv", "target": 1, "reward": {"normal_packs": 1, "cards": [{"codigo": "0104", "cantidad": 1}]}, "metric": "wins", "scope": "event", "required_card": "0104"}, {"id": "win_three_javieriv", "title": "Gana 3 partidas con un mazo que incluya al menos 1 Javieriv", "target": 3, "reward": {"packs": 1, "cards": [{"codigo": "0104", "cantidad": 1}]}, "metric": "wins", "scope": "event", "required_card": "0104"}]');
insert into aamix_private.event_definitions values('kajido_2026','Cumpleaños Kajido','0105','2026-11-25','2026-11-27','Este 26/11 celebramos el cumpleaños de Kajido. Completa las misiones para obtener una carta Kajido de recompensa.','[{"id": "play_one", "title": "Juega 1 partida", "target": 1, "reward": {"restos": 25}, "metric": "played", "scope": "event"}, {"id": "win_one_kajido", "title": "Gana 1 partida con Mazo Kajido", "target": 1, "reward": {"restos": 50, "deck_design": "custom_kajido"}, "metric": "wins", "scope": "event", "deck_id": "kajido"}, {"id": "win_three_kajido", "title": "Gana 3 partidas con Mazo Kajido", "target": 3, "reward": {"restos": 100, "cards": [{"codigo": "0105", "cantidad": 1}]}, "metric": "wins", "scope": "event", "deck_id": "kajido"}]');

create function aamix_private.events_inventory() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); stamp timestamptz:=aamix_private.event_clock();
 today date:=(stamp at time zone 'America/Santiago')::date; e record; m jsonb;
 states jsonb; active_events jsonb:='[]'; progress bigint; period text; next_at timestamptz;
begin
 if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
 next_at:=(today+1)::timestamp at time zone 'America/Santiago';
 select least(next_at,min(boundary)) into next_at from (
  select start_day::timestamp at time zone 'America/Santiago' boundary from aamix_private.event_definitions
  union all select (end_day+1)::timestamp at time zone 'America/Santiago' from aamix_private.event_definitions
 ) dates where boundary>stamp;
 for e in select * from aamix_private.event_definitions where today between start_day and end_day order by start_day,id loop
  states:='[]';
  for m in select value from jsonb_array_elements(e.missions) loop
   period:=case when m->>'scope'='daily' then today::text else 'event' end;
   if m->>'metric'='login' then
    select count(*) into progress from aamix_private.event_visits v where v.user_id=uid and v.event_id=e.id and v.day=today;
   else
    select count(*) into progress from public.aamix_match_receipts r
    where r.user_id=uid and r.finished_at>=e.start_day::timestamp at time zone 'America/Santiago'
     and r.finished_at<(e.end_day+1)::timestamp at time zone 'America/Santiago' and r.finished_at<=stamp
     and r.result in('victory','defeat') and (m->>'metric'='played' or r.result='victory')
     and (not(m ? 'deck_id') or r.deck_id=m->>'deck_id')
     and (not(m ? 'required_card') or exists(select 1 from jsonb_array_elements(coalesce(r.player_deck->'cartas','[]')) c
       where c->>'codigo'=m->>'required_card' and (c->>'cantidad')::integer>=1));
   end if;
   states:=states||jsonb_build_array(m||jsonb_build_object('progress',least(progress,(m->>'target')::integer),
    'period_key',period,'claimed',exists(select 1 from aamix_private.event_claims c where c.user_id=uid and c.event_id=e.id and c.mission_id=m->>'id' and c.period_key=period)));
  end loop;
  active_events:=active_events||jsonb_build_array(jsonb_build_object('id',e.id,'title',e.title,'card_code',e.card_code,
   'start_day',e.start_day,'end_day',e.end_day,'summary',e.summary,'missions',states));
 end loop;
 return jsonb_build_object('events',active_events,'server_day',today,'server_time',extract(epoch from stamp),
  'events_valid_until',extract(epoch from next_at),'events_timezone','America/Santiago');
end $$;
revoke all on function aamix_private.events_inventory() from public,anon,authenticated;
grant execute on function aamix_private.events_inventory() to authenticated;
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
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb))||aamix_private.deck_designs_inventory()||aamix_private.events_inventory();
end $function$
;

create function aamix_private.events_sync() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); today date:=(aamix_private.event_clock() at time zone 'America/Santiago')::date;
begin
 insert into aamix_private.event_visits(user_id,event_id,day)
  select uid,id,today from aamix_private.event_definitions where today between start_day and end_day
  on conflict do nothing;
 return public.aamix_inventory();
end $$;
revoke all on function aamix_private.events_sync() from public,anon,authenticated;
grant execute on function aamix_private.events_sync() to authenticated;
create function public.aamix_events_sync() returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.events_sync() $$;
revoke all on function public.aamix_events_sync() from public,anon,authenticated;
grant execute on function public.aamix_events_sync() to authenticated;

create function aamix_private.claim_event_mission(p_event_id text,p_mission_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); e jsonb; m jsonb; prize jsonb; granted uuid; period text;
begin
 select value into e from jsonb_array_elements(aamix_private.events_inventory()->'events') where value->>'id'=p_event_id;
 if e is null then raise exception 'AAMIX_EVENT_INACTIVE' using errcode='22023'; end if;
 select value into m from jsonb_array_elements(e->'missions') where value->>'id'=p_mission_id;
 if m is null then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023'; end if;
 period:=m->>'period_key';
 if not (m->>'claimed')::boolean and (m->>'progress')::integer<(m->>'target')::integer then
  raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023';
 end if;
 prize:=m->'reward';
 insert into aamix_private.event_claims(user_id,event_id,mission_id,period_key,reward)
  values(uid,p_event_id,p_mission_id,period,prize) on conflict do nothing returning user_id into granted;
 if granted is not null then
  update public.aamix_rewards_state set restos=restos+coalesce((prize->>'restos')::integer,0),
   packs=packs+coalesce((prize->>'packs')::integer,0),normal_packs=normal_packs+coalesce((prize->>'normal_packs')::integer,0) where user_id=uid;
  insert into public.aamix_collection(user_id,code,quantity)
   select uid,c->>'codigo',(c->>'cantidad')::integer from jsonb_array_elements(coalesce(prize->'cards','[]')) c order by c->>'codigo'
   on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
  if prize ? 'deck_design' then
   insert into aamix_private.event_design_unlocks(user_id,design,event_id) values(uid,prize->>'deck_design',p_event_id) on conflict do nothing;
  end if;
 else
  select reward into prize from aamix_private.event_claims where user_id=uid and event_id=p_event_id and mission_id=p_mission_id and period_key=period;
 end if;
 return public.aamix_inventory()||jsonb_build_object('already_claimed',granted is null,'event_id',p_event_id,'mission_id',p_mission_id,'event_reward',prize);
end $$;
revoke all on function aamix_private.claim_event_mission(text,text) from public,anon,authenticated;
grant execute on function aamix_private.claim_event_mission(text,text) to authenticated;
create function public.aamix_claim_event_mission(p_event_id text,p_mission_id text) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.claim_event_mission(p_event_id,p_mission_id) $$;
revoke all on function public.aamix_claim_event_mission(text,text) from public,anon,authenticated;
grant execute on function public.aamix_claim_event_mission(text,text) to authenticated;

alter table aamix_private.gift_code_rewards add column event_id text references aamix_private.event_definitions(id);
insert into aamix_private.gift_code_rewards(gift_code,reward_name,packs,normal_packs,restos,event_id)
 values('BIENVENIDAA','1 sobre TC, 1 carta aleatoria y 100 Restos',1,1,100,'bienvenida_2026');
insert into aamix_private.gift_code_rewards(gift_code,reward_name,cards,event_id)
 values('GATONEGRO','1 Bigotes','[{"codigo":"01b","cantidad":1}]','halloween_2026');
insert into aamix_private.gift_code_rewards(gift_code,reward_name,deck_id,event_id)
 values('CUMPLEKAJIDO','Mazo Kajido','kajido','kajido_2026');
CREATE OR REPLACE FUNCTION aamix_private.redeem_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid:=aamix_private.lock_rewards(); normalized text:=upper(btrim(p_code));
  configured aamix_private.gift_code_rewards%rowtype; chosen aamix_private.base_decks%rowtype;
  award_cards jsonb:='[]'::jsonb; granted uuid; claimed_design text;
begin
  -- A redeemed cosmetic code is a stable receipt, even if future code metadata changes or expires.
  select deck_design into claimed_design from public.aamix_code_redemptions where user_id=uid and gift_code=normalized;
  if claimed_design is not null then
    return public.aamix_inventory()||jsonb_build_object('already_redeemed',true,'redeemed_code',normalized,
      'reward_name',case claimed_design when 'custom_tsuki_akira' then 'Diseño de mazo Tsuki y Akira'
        when 'custom_chanchuus' then 'Diseño de mazo Granjita de Chanchuus' when 'custom_viborin' then 'Diseño de mazo Viborín' end,
      'reward_deck_id',null,'reward_cards','[]'::jsonb,'reward_packs',0,'reward_restos',0,'reward_normal_packs',0,
      'reward_cover',claimed_design,'reward_design',claimed_design);
  end if;
  select * into configured from aamix_private.gift_code_rewards where gift_code=normalized;
  if not found then raise exception 'AAMIX_INVALID_CODE' using errcode='22023'; end if;
  if configured.event_id is not null
    and not exists(select 1 from public.aamix_code_redemptions where user_id=uid and gift_code=normalized)
    and not exists(select 1 from aamix_private.event_definitions e where e.id=configured.event_id
      and (aamix_private.event_clock() at time zone 'America/Santiago')::date between e.start_day and e.end_day) then
    raise exception 'AAMIX_CODE_INACTIVE' using errcode='22023';
  end if;
  if configured.deck_id is not null then
    select * into strict chosen from aamix_private.base_decks where id=configured.deck_id;
    award_cards:=chosen.cards;
  elsif configured.cards is not null then award_cards:=configured.cards;
  end if;
  if exists(select 1 from jsonb_array_elements(award_cards) e
      where not exists(select 1 from aamix_private.catalog_codes c where c.code=e->>'codigo')
         or coalesce((e->>'cantidad')::integer,0)<=0) then
    raise exception 'Invalid server reward configuration' using errcode='22023';
  end if;
  -- Nested lock is safe: all balance writers serialize on this same UUID row.
  -- The existing registration currency award remains exactly once per account.
  if configured.deck_design is null then perform aamix_private.ensure_restos_welcome(); end if;
  insert into public.aamix_code_redemptions(user_id,gift_code,deck_design) values(uid,normalized,configured.deck_design)
    on conflict(user_id,gift_code) do nothing returning user_id into granted;
  if granted is not null and configured.deck_design is null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',sum((e->>'cantidad')::integer)::integer
      from jsonb_array_elements(award_cards) e group by e->>'codigo' order by e->>'codigo'
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    if configured.deck_id is not null then
      insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
        values(uid,chosen.id,chosen.name,chosen.cover,chosen.cards) on conflict(user_id,deck_id) do nothing;
    end if;
    update public.aamix_rewards_state set packs=packs+configured.packs,
      restos=restos+configured.restos,normal_packs=normal_packs+configured.normal_packs where user_id=uid;
  end if;
  if granted is not null then claimed_design:=configured.deck_design; end if;
  return public.aamix_inventory()||jsonb_build_object('already_redeemed',granted is null,'redeemed_code',normalized,
    'reward_name',configured.reward_name,'reward_deck_id',configured.deck_id,'reward_cards',award_cards,
    'reward_packs',configured.packs,'reward_restos',configured.restos,'reward_normal_packs',configured.normal_packs,
    'reward_cover',claimed_design,'reward_design',claimed_design);
end $function$
;

alter table public.aamix_custom_decks drop constraint aamix_custom_decks_cover_check;
alter table public.aamix_custom_decks add constraint aamix_custom_decks_cover_check check(cover in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin','custom_kajido'));
CREATE OR REPLACE FUNCTION aamix_private.deck_designs_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); unlocked jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select coalesce(jsonb_agg(design.id order by design.position),'[]'::jsonb) into unlocked
  from (values('custom_tsuki_akira',1),('custom_chanchuus',2),('custom_viborin',3),('custom_kajido',4)) design(id,position)
  where exists(
    select 1 from public.aamix_code_redemptions redeemed
    where redeemed.user_id=uid and redeemed.deck_design=design.id
  ) or exists(select 1 from aamix_private.event_design_unlocks earned where earned.user_id=uid and earned.design=design.id);
  return jsonb_build_object(
    'available_custom_covers','["custom_transmision","custom_restos"]'::jsonb||unlocked,
    'unlocked_deck_designs',unlocked);
end $function$
;
CREATE OR REPLACE FUNCTION aamix_private.save_custom_deck(p_request_id uuid, p_deck_id text, p_nombre text, p_portada text, p_cartas jsonb, p_draft boolean, p_expected_revision integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); d public.aamix_custom_decks%rowtype;
  old_request aamix_private.custom_deck_requests%rowtype; payload jsonb; saved jsonb; canonical_cards jsonb;
  normalized_id text:=coalesce(p_deck_id,''); normalized_name text:=btrim(p_nombre);
begin
  if p_request_id is null or p_expected_revision is null or p_expected_revision<0 or p_draft is null
    or normalized_name is null or char_length(normalized_name) not between 1 and 48 or normalized_name ~ '[[:cntrl:]]'
    or p_portada is null or p_portada not in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin','custom_kajido')
    or p_cartas is null or octet_length(p_cartas::text)>8192 then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
  payload:=jsonb_build_object('id',normalized_id,'nombre',normalized_name,'portada',p_portada,'cartas',p_cartas,'draft',p_draft,'expected_revision',p_expected_revision);
  select * into old_request from aamix_private.custom_deck_requests where user_id=uid and request_id=p_request_id;
  if found then
    if old_request.payload<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return public.aamix_inventory()||jsonb_build_object('saved_deck',old_request.saved_deck,'last_saved_deck',old_request.saved_deck);
  end if;
  if p_portada not in('custom_transmision','custom_restos') and not exists(
    select 1 from public.aamix_code_redemptions redeemed
    where redeemed.user_id=uid and redeemed.deck_design=p_portada
  ) and not exists(select 1 from aamix_private.event_design_unlocks earned where earned.user_id=uid and earned.design=p_portada) then raise exception 'AAMIX_DECK_COVER_LOCKED' using errcode='22023'; end if;
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
end $function$
;
CREATE OR REPLACE FUNCTION aamix_private.custom_cards(p_uid uuid, p_cards jsonb, p_draft boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  -- Playability size rule is deliberately centralized here; all newly saved decks require a Resource, including drafts.
  if not p_draft and (total<>40) then raise exception 'AAMIX_DECK_SIZE' using errcode='22023'; end if;
  if resources<1 then raise exception 'AAMIX_DECK_INITIAL_RESOURCE' using errcode='22023'; end if;
  return coalesce((select jsonb_agg(sorted.card order by sorted.card->>'codigo') from jsonb_array_elements(normalized) as sorted(card)),'[]'::jsonb);
end $function$
;
notify pgrst,'reload schema';
