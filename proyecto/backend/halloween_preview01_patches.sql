-- Changes below affect only the isolated preview schemas.
create function aamix_hw01_private.canonical_card(code text) returns text language sql immutable set search_path='' as $$select case code when 'H01' then '0104' when 'H02' then '0130' when 'H03' then '0127' when 'H04' then '0102' when 'H05' then '0103' else code end$$;
revoke all on function aamix_hw01_private.canonical_card(text) from public,anon,authenticated;
grant execute on function aamix_hw01_private.canonical_card(text) to authenticated;
insert into aamix_hw01_private.catalog_codes(code) values('H01'),('H02'),('H03'),('H04'),('H05');
insert into aamix_hw01_private.reward_catalog(code,name,card_class,special_weight,is_promotional,is_singular)
 select h.code,r.name,r.card_class,r.special_weight,false,r.is_singular from(values('H01','0104'),('H02','0130'),('H03','0127'),('H04','0102'),('H05','0103')) h(code,base) join aamix_hw01_private.reward_catalog r on r.code=h.base;
alter table aamix_hw01.aamix_match_receipts add column event_battle boolean not null default false;
alter table aamix_hw01_private.mp_rooms add column host_rematch boolean not null default false,add column guest_rematch boolean not null default false,add column host_rematch_ready boolean not null default false,add column guest_rematch_ready boolean not null default false,add column rematch_cancelled boolean not null default false,add column rematch_room uuid,add column host_next_deck jsonb,add column guest_next_deck jsonb;
create table aamix_hw01_private.hw_wallet(user_id uuid primary key references auth.users(id) on delete cascade,halloween_packs integer not null default 10 check(halloween_packs>=0),friend_added boolean not null default false,traded boolean not null default false);
create table aamix_hw01_private.hw_mp_rewards(user_id uuid not null references auth.users(id) on delete cascade,match_id uuid not null references aamix_hw01.aamix_match_receipts(match_id),primary key(user_id,match_id));
create table aamix_hw01_private.mp_rematch_requests(user_id uuid not null references auth.users(id) on delete cascade,request_id uuid not null,payload jsonb not null,primary key(user_id,request_id));
do $$declare t text;begin foreach t in array array['hw_wallet','hw_mp_rewards','mp_rematch_requests'] loop execute format('alter table aamix_hw01_private.%I enable row level security',t);execute format('revoke all on aamix_hw01_private.%I from public,anon,authenticated',t);execute format('create policy server_only on aamix_hw01_private.%I for all to anon,authenticated using(false) with check(false)',t);end loop;end$$;
do $$declare c record;begin for c in select conname from pg_constraint where conrelid='aamix_hw01.aamix_pack_openings'::regclass and contype='c' and pg_get_constraintdef(oid) like '%kind%' loop execute format('alter table aamix_hw01.aamix_pack_openings drop constraint %I',c.conname);end loop;end$$;
alter table aamix_hw01.aamix_pack_openings add constraint halloween_pack_kind check(kind in('tc','normal_card','halloween'));
CREATE OR REPLACE FUNCTION aamix_hw01_private.draw_pack()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare codes jsonb := '[]'::jsonb; selected text; ticket double precision; slot integer;
begin
  perform aamix_hw01_private.reward_user();
  select code into strict selected from aamix_hw01_private.reward_catalog
    where not is_promotional and code not like 'H%' and card_class='Recurso' order by random() limit 1;
  codes := codes || jsonb_build_array(selected);
  for slot in 2..5 loop
    if slot=5 and random()<0.30 then
      ticket := random()*100;
      select code into strict selected from (
        select code,sum(special_weight) over(order by code rows unbounded preceding) as cumulative
        from aamix_hw01_private.reward_catalog where not is_promotional and code not like 'H%' and special_weight>0
      ) weighted where cumulative>ticket order by cumulative limit 1;
    else
      select code into strict selected from aamix_hw01_private.reward_catalog
        where not is_promotional and code not like 'H%' and card_class<>'Recurso' and special_weight=0 order by random() limit 1;
    end if;
    codes := codes || jsonb_build_array(selected);
  end loop;
  if codes ?| array['01a','01b','01c','01d','01e','01f'] then
    raise exception 'Promotional cards are forbidden in packs' using errcode='23514';
  end if;
  return codes;
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.draw_normal_card()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare selected text;
begin
  perform aamix_hw01_private.reward_user();
  select code into strict selected from aamix_hw01_private.reward_catalog
    where not is_promotional and code not like 'H%' and card_class<>'Recurso' and special_weight=0 order by random() limit 1;
  return jsonb_build_array(selected);
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.shop_catalog()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform aamix_hw01_private.reward_user();
  return coalesce((select jsonb_agg(jsonb_build_object('code',code,'price',
    case when code in('0103','0105','0115','0119') then 500 else 150 end) order by code)
    from aamix_hw01_private.reward_catalog where not is_promotional and code not like 'H%' and card_class<>'Recurso'),'[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.purchase_card(p_request_id uuid, p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_hw01_private.lock_rewards(); receipt aamix_hw01.aamix_shop_purchases%rowtype;
  cost integer; already boolean;
begin
  if p_request_id is null then raise exception 'Purchase request UUID required' using errcode='22023'; end if;
  select * into receipt from aamix_hw01.aamix_shop_purchases where user_id=uid and request_id=p_request_id;
  already:=found;
  if already then
    if receipt.code is distinct from p_code then raise exception 'AAMIX_PURCHASE_REQUEST_MISMATCH' using errcode='22023'; end if;
  else
    select case when code in('0103','0105','0115','0119') then 500 else 150 end into cost
      from aamix_hw01_private.reward_catalog where code=p_code and not is_promotional and code not like 'H%' and card_class<>'Recurso';
    if not found then raise exception 'AAMIX_CARD_NOT_FOR_SALE' using errcode='22023'; end if;
    perform aamix_hw01_private.ensure_restos_welcome();
    update aamix_hw01.aamix_rewards_state set restos=restos-cost where user_id=uid and restos>=cost;
    if not found then raise exception 'AAMIX_INSUFFICIENT_RESTOS' using errcode='22023'; end if;
    insert into aamix_hw01.aamix_shop_purchases(user_id,request_id,code,price) values(uid,p_request_id,p_code,cost) returning * into receipt;
    insert into aamix_hw01.aamix_collection(user_id,code,quantity) values(uid,p_code,1)
      on conflict(user_id,code) do update set quantity=aamix_hw01.aamix_collection.quantity+1;
  end if;
  return aamix_hw01.aamix_inventory()||jsonb_build_object('already_purchased',already,'purchase_code',receipt.code,'purchase_price',receipt.price,
    'purchase',jsonb_build_object('purchase_id',receipt.purchase_id,'request_id',receipt.request_id,'code',receipt.code,'price',receipt.price,'purchased_at',receipt.purchased_at));
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.avatar_allowed_v170(p_uid uuid, p_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select exists(select 1 from aamix_hw01_private.reward_catalog c where c.code=p_code and c.card_class='Aliado' and c.code not like 'H%'
 and ((not c.is_promotional and c.code not in('0112','0113','0114','0126')) or (c.code in('0112','0113','0114','0126','01a','01b') and exists(select 1 from aamix_hw01_private.avatar_unlocks_v170 u where u.user_id=p_uid and u.code=p_code))))
$function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.check_collection_v170(p_uid uuid, p_code text, p_quantity integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d record;
begin
 if p_quantity>=10 then
  for d in select id from aamix_hw01_private.milestone_definitions_v170 where not secret and card_code=p_code loop
   perform aamix_hw01_private.complete_milestone_v170(p_uid,d.id);
  end loop;
 end if;
 if exists(select 1 from aamix_hw01_private.reward_catalog where code=p_code and not is_promotional)
  and not exists(select 1 from aamix_hw01_private.reward_catalog c where not c.is_promotional and c.code not like 'H%' and not exists(
   select 1 from aamix_hw01.aamix_collection o where o.user_id=p_uid and o.code=c.code and o.quantity>0)) then
  perform aamix_hw01_private.complete_milestone_v170(p_uid,'collect_all_standard');
 end if;
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.custom_cards(p_uid uuid, p_cards jsonb, p_draft boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e jsonb; code_value text; amount integer; owned integer; c aamix_hw01_private.reward_catalog%rowtype;
  total integer:=0; resources integer:=0; seen text[]:='{}'; normalized jsonb:='[]'; families jsonb:='{}'; family text; family_amount integer;
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
    select * into c from aamix_hw01_private.reward_catalog where code=code_value;
    if not found then raise exception 'AAMIX_UNKNOWN_CARD' using errcode='22023'; end if;
    family:=aamix_hw01_private.canonical_card(code_value); family_amount:=coalesce((families->>family)::integer,0)+amount; families:=families||jsonb_build_object(family,family_amount);
    if c.card_class<>'Recurso' and family_amount>(case when c.is_singular then 1 else 3 end) then raise exception 'AAMIX_DECK_COPY_LIMIT' using errcode='22023'; end if;
    select quantity into owned from aamix_hw01.aamix_collection where user_id=p_uid and code=code_value;
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
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.challenges_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); status jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select jsonb_agg(d || jsonb_build_object(
    'unlocked',true or not exists(select 1 from generate_series(1,(d->>'stage')::integer-1) previous(stage)
      where not exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)),
    'completed',exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer),
    'reward_claimed',exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer)
  ) order by (d->>'stage')::integer) into status from jsonb_array_elements(aamix_hw01_private.challenge_definitions()) d;
  return status;
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.begin_challenge_match(p_request_id uuid, p_deck_id text, p_stage integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_hw01_private.lock_rewards(); receipt aamix_hw01.aamix_match_receipts%rowtype;
  definition jsonb; opponent jsonb; d jsonb;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  select e into definition from jsonb_array_elements(aamix_hw01_private.challenge_definitions()) e where (e->>'stage')::integer=p_stage;
  if not found then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;
  select * into receipt from aamix_hw01.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found then
    if receipt.deck_id<>p_deck_id or receipt.challenge_stage is distinct from p_stage then raise exception 'Request UUID already used for a different match' using errcode='22023'; end if;
    d:=coalesce(receipt.player_deck,aamix_hw01_private.mp_deck(uid,p_deck_id));
  else
    if false and exists(select 1 from generate_series(1,p_stage-1) previous(stage) where not exists(
      select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023'; end if;
    d:=aamix_hw01_private.mp_deck(uid,p_deck_id);
    select jsonb_build_object('id',id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) into strict opponent
      from aamix_hw01_private.base_decks where id=definition->>'deck_id';
    insert into aamix_hw01.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent,player_deck)
      values(uid,p_request_id,p_deck_id,p_stage,opponent,d) returning * into receipt;
  end if;
  return aamix_hw01.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result,
    'challenge_stage',receipt.challenge_stage,'challenge_opponent',receipt.challenge_opponent,'match_deck',d);
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.finish_match(p_match_id uuid, p_result text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_hw01_private.lock_rewards(); receipt aamix_hw01.aamix_match_receipts%rowtype;
  today date:=(now() at time zone 'America/Santiago')::date; definition jsonb; granted integer;
  prize integer:=0; already_completed boolean:=false; repeat_prize integer:=0; all_completed boolean:=false;
begin
  if p_result is null or p_result not in('victory','defeat') then raise exception 'Completed victory or defeat required' using errcode='22023'; end if;
  select * into receipt from aamix_hw01.aamix_match_receipts where user_id=uid and match_id=p_match_id for update;
  if not found then raise exception 'Unknown match receipt' using errcode='22023'; end if;
  if receipt.challenge_stage is not null then
    select d into strict definition from jsonb_array_elements(aamix_hw01_private.challenge_definitions()) d where (d->>'stage')::integer=receipt.challenge_stage;
    if receipt.challenge_opponent->>'id' is distinct from definition->>'deck_id' then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;
    already_completed:=exists(select 1 from aamix_hw01.aamix_challenge_completions where user_id=uid and stage=receipt.challenge_stage);
  end if;
  if receipt.result is null then
    if false and receipt.challenge_stage is not null and exists(select 1 from generate_series(1,receipt.challenge_stage-1) previous(stage)
      where not exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then
      raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023';
    end if;
    all_completed:=not exists(select 1 from generate_series(1,5) s(stage) where not exists(
      select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=s.stage));
    if receipt.challenge_stage is not null and p_result='victory' and all_completed then repeat_prize:=5;end if;
    update aamix_hw01.aamix_match_receipts set finished_at=now(),result=p_result,challenge_repeat_restos=repeat_prize where match_id=receipt.match_id;
    if repeat_prize>0 then update aamix_hw01.aamix_rewards_state set restos=restos+repeat_prize where user_id=uid;end if;
    insert into aamix_hw01.aamix_daily_missions(user_id,mission_day,completed_match_id) values(uid,today,receipt.match_id) on conflict(user_id,mission_day) do nothing;
    if receipt.challenge_stage is not null and p_result='victory' then
      insert into aamix_hw01.aamix_challenge_completions(user_id,stage,winning_match_id,reward_packs)
        values(uid,receipt.challenge_stage,receipt.match_id,(definition->>'reward_packs')::integer)
        on conflict(user_id,stage) do nothing returning stage into granted;
      if granted is not null then
        prize:=(definition->>'reward_packs')::integer;
        update aamix_hw01.aamix_rewards_state set packs=packs+prize where user_id=uid;
      end if;
    end if;
  elsif receipt.result<>p_result then raise exception 'Match already finished with another result' using errcode='22023'; end if;
  return aamix_hw01.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',p_result,
    'challenge_stage',receipt.challenge_stage,'challenge_reward_packs',prize,'challenge_already_completed',already_completed,
    'challenge_repeat_restos',case when receipt.result is null then repeat_prize else receipt.challenge_repeat_restos end);
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.mp_response(p_room_id uuid, p_uid uuid, p_since integer DEFAULT '-1'::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r aamix_hw01_private.mp_rooms%rowtype; s integer; data jsonb;
begin
  select * into strict r from aamix_hw01_private.mp_rooms where id=p_room_id;
  s:=case when p_uid=r.host_id then 0 when p_uid=r.guest_id then 1 else -1 end;
  if s=-1 then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  data:=jsonb_build_object('protocol',3,'ruleset_version',r.ruleset_version,'room_version',r.room_version,'confirmed',jsonb_build_array(r.host_confirmed,r.guest_confirmed),'room_id',r.id,'code',r.code,'status',r.status,'slot',s,'revision',r.revision,
    'actor_slot',r.actor_slot,'winner',r.winner,'expires_at',r.expires_at,'last_error',r.last_error,
    'finish_reason',r.finish_reason,'opponent_online',case when s=0 then r.guest_seen>now()-interval '20 seconds' else r.host_seen>now()-interval '20 seconds' end,
    'players',jsonb_build_array(
      jsonb_build_object('slot',0,'avatar_code',(select avatar_code from aamix_hw01.aamix_rewards_state where user_id=r.host_id),'name',r.host_name,'deck_id',r.host_deck->>'id','deck_name',r.host_deck->>'nombre','cover',r.host_deck->>'portada'),
      case when r.guest_id is null then null else jsonb_build_object('slot',1,'avatar_code',(select avatar_code from aamix_hw01.aamix_rewards_state where user_id=r.guest_id),'name',r.guest_name,'deck_id',r.guest_deck->>'id','deck_name',r.guest_deck->>'nombre','cover',r.guest_deck->>'portada') end));
  if s=0 then
    data:=data||jsonb_build_object('commands',coalesce((
      select jsonb_agg(jsonb_build_object('request_id',c.request_id,'slot',c.slot,'method',c.method,'args',c.args,'revision',c.revision) order by c.created_at)
      from aamix_hw01_private.mp_commands c where c.room_id=r.id and c.status='pending'),'[]'::jsonb));
    if r.revision=0 or p_since=-1 then
      data:=data||jsonb_build_object('host_deck',r.host_deck,'guest_deck',r.guest_deck);
      data:=jsonb_set(data,'{players,0,deck}',r.host_deck);
    if r.guest_id is not null then data:=jsonb_set(data,'{players,1,deck}',r.guest_deck); end if;
    end if;
  end if;
  if p_since<>r.revision then data:=data||jsonb_build_object('state',case s when 0 then r.host_state else r.guest_view end); end if;
  return data||jsonb_build_object('rematch',jsonb_build_object('requested',jsonb_build_array(r.host_rematch,r.guest_rematch),'ready',jsonb_build_array(r.host_rematch_ready,r.guest_rematch_ready),'cancelled',r.rematch_cancelled,'next_room_id',r.rematch_room,'deck_id',case s when 0 then r.host_next_deck->>'id' else r.guest_next_deck->>'id' end));
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.mp_notify_room()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if tg_op='UPDATE' and new.revision=old.revision and new.status=old.status
    and new.guest_id is not distinct from old.guest_id
    and new.host_confirmed=old.host_confirmed and new.guest_confirmed=old.guest_confirmed and new.room_version=old.room_version then return null; end if;
  perform realtime.send(aamix_hw01_private.mp_response(new.id,new.host_id,-1),'room','aamix:user:'||new.host_id::text,true);
  if new.guest_id is not null then
    perform realtime.send(aamix_hw01_private.mp_response(new.id,new.guest_id,-1),'room','aamix:user:'||new.guest_id::text,true);
  end if;
  return null;
end $function$;

create function aamix_hw01_private.halloween_definition() returns jsonb language sql immutable set search_path='' as $event$ select '{"id": "halloween_2026", "title": "EVENTO HALLOWEEN", "card_code": "0128", "start_day": "2026-10-30", "end_day": "2026-11-01", "battle": true, "battle_id": "halloween", "preview": true, "summary": "La festividad del terror se toma AAMIX, encuentra las cinco Cartas Exclusivas del evento y completa las misiones para obtener recompensas. Durante este evento, los ganadores de batallas multijugador recibirán 1 Sobre AAMIX Halloween.", "missions": [{"id": "play_three", "title": "Juega 3 partidas", "target": 3, "metric": "played", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "play_five", "title": "Juega 5 partidas", "target": 5, "metric": "played", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "win_three", "title": "Gana 3 partidas", "target": 3, "metric": "wins", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "trade_one", "title": "Intercambia 1 carta", "target": 1, "metric": "trades", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "friend_one", "title": "Añade 1 Amigo", "target": 1, "metric": "friends", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "event_win_five", "title": "Gana 5 veces la Partida de Evento", "target": 5, "metric": "event_wins", "scope": "event", "reward": {"cards": [{"codigo": "H05", "cantidad": 1}]}}]}'::jsonb $event$;
create function aamix_hw01_private.halloween_deck() returns jsonb language sql immutable set search_path='' as $deck$select '{
  "id": "halloween",
  "nombre": "Mazo Halloween",
  "portada": "custom_restos",
  "recurso_inicial": "0100",
  "cartas": [
    {
      "codigo": "0100",
      "cantidad": 17
    },
    {
      "codigo": "H04",
      "cantidad": 3
    },
    {
      "codigo": "0128",
      "cantidad": 3
    },
    {
      "codigo": "H01",
      "cantidad": 3
    },
    {
      "codigo": "H02",
      "cantidad": 1
    },
    {
      "codigo": "H03",
      "cantidad": 1
    },
    {
      "codigo": "01b",
      "cantidad": 1
    },
    {
      "codigo": "0112",
      "cantidad": 2
    },
    {
      "codigo": "0113",
      "cantidad": 2
    },
    {
      "codigo": "H05",
      "cantidad": 1
    },
    {
      "codigo": "0116",
      "cantidad": 2
    },
    {
      "codigo": "0120",
      "cantidad": 2
    },
    {
      "codigo": "0124",
      "cantidad": 2
    }
  ]
}
'::jsonb $deck$;
