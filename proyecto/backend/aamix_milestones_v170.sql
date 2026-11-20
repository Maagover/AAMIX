-- AAMIX1.7: additive achievements, permanent cosmetic entitlements and durable notices.
create table aamix_private.milestone_definitions_v170(
 id text primary key,title text not null,secret boolean not null,target integer not null,
 card_code text references aamix_private.catalog_codes(code),reward_kind text not null check(reward_kind in('card','avatar','design')),reward_code text not null
);
insert into aamix_private.milestone_definitions_v170 values
 ('collect_ten_sam','Colecciona 10 cartas de Sam',false,10,'0114','avatar','0114'),
 ('collect_ten_yuri','Colecciona 10 cartas de Yuri',false,10,'0112','avatar','0112'),
 ('collect_ten_celia','Colecciona 10 cartas de Celia',false,10,'0113','avatar','0113'),
 ('collect_ten_viborin','Colecciona 10 Viborín',false,10,'0126','avatar','0126'),
 ('challenge_complete','Completa el Desafío AAMIX',true,1,null,'card','01d'),
 ('challenge_maagover','Derrota a Mazo Maagover en Desafío AAMIX',true,1,null,'design','custom_maagover'),
 ('challenge_girabl','Derrota a Mazo Girabl en Desafío AAMIX',true,1,null,'design','custom_girabl'),
 ('collect_all_standard','Obtén todas las cartas no promocionales',true,1,null,'card','01f');
create table aamix_private.milestones_v170(
 user_id uuid not null references auth.users(id) on delete cascade,
 mission_id text not null references aamix_private.milestone_definitions_v170(id),completed_at timestamptz not null default now(),
 claimed_at timestamptz,acknowledged_at timestamptz,primary key(user_id,mission_id)
);
create index milestone_notices_v170 on aamix_private.milestones_v170(user_id,completed_at) where claimed_at is not null and acknowledged_at is null;
create table aamix_private.avatar_unlocks_v170(
 user_id uuid not null references auth.users(id) on delete cascade,code text not null references aamix_private.catalog_codes(code),
 source text not null,unlocked_at timestamptz not null default now(),primary key(user_id,code)
);
create table aamix_private.mission_design_unlocks_v170(
 user_id uuid not null references auth.users(id) on delete cascade,design text not null check(design in('custom_maagover','custom_girabl')),
 mission_id text not null references aamix_private.milestone_definitions_v170(id),unlocked_at timestamptz not null default now(),primary key(user_id,design)
);
do $$ declare t text;begin foreach t in array array['milestone_definitions_v170','milestones_v170','avatar_unlocks_v170','mission_design_unlocks_v170'] loop
 execute format('alter table aamix_private.%I enable row level security',t);
 execute format('create policy server_only_v170 on aamix_private.%I for all to anon,authenticated using(false) with check(false)',t);
 execute format('revoke all on aamix_private.%I from public,anon,authenticated',t);
end loop;end $$;

create function aamix_private.grant_milestone_v170(p_uid uuid,p_id text) returns void
language plpgsql security definer set search_path='' as $$
declare m aamix_private.milestones_v170%rowtype;d aamix_private.milestone_definitions_v170%rowtype;
begin
 select * into m from aamix_private.milestones_v170 where user_id=p_uid and mission_id=p_id for update;
 if not found or m.claimed_at is not null then return;end if;
 select * into strict d from aamix_private.milestone_definitions_v170 where id=p_id;
 update aamix_private.milestones_v170 set claimed_at=now(),acknowledged_at=case when d.secret then null else now() end where user_id=p_uid and mission_id=p_id;
 if d.reward_kind='avatar' then
  insert into aamix_private.avatar_unlocks_v170(user_id,code,source) values(p_uid,d.reward_code,p_id) on conflict do nothing;
 elsif d.reward_kind='design' then
  insert into aamix_private.mission_design_unlocks_v170(user_id,design,mission_id) values(p_uid,d.reward_code,p_id) on conflict do nothing;
 else
  insert into public.aamix_collection(user_id,code,quantity) values(p_uid,d.reward_code,1) on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+1;
 end if;
end $$;
create function aamix_private.complete_milestone_v170(p_uid uuid,p_id text) returns void
language plpgsql security definer set search_path='' as $$
begin
 insert into aamix_private.milestones_v170(user_id,mission_id) values(p_uid,p_id) on conflict do nothing;
 if exists(select 1 from aamix_private.milestone_definitions_v170 where id=p_id and secret) then perform aamix_private.grant_milestone_v170(p_uid,p_id);end if;
end $$;
create function aamix_private.check_collection_v170(p_uid uuid,p_code text,p_quantity integer) returns void
language plpgsql security definer set search_path='' as $$
declare d record;
begin
 if p_quantity>=10 then
  for d in select id from aamix_private.milestone_definitions_v170 where not secret and card_code=p_code loop
   perform aamix_private.complete_milestone_v170(p_uid,d.id);
  end loop;
 end if;
 if exists(select 1 from aamix_private.reward_catalog where code=p_code and not is_promotional)
  and not exists(select 1 from aamix_private.reward_catalog c where not c.is_promotional and not exists(
   select 1 from public.aamix_collection o where o.user_id=p_uid and o.code=c.code and o.quantity>0)) then
  perform aamix_private.complete_milestone_v170(p_uid,'collect_all_standard');
 end if;
end $$;
create function aamix_private.collection_milestone_trigger_v170() returns trigger
language plpgsql security definer set search_path='' as $$ begin
 perform aamix_private.check_collection_v170(new.user_id,new.code,new.quantity);return new;
end $$;
create trigger collection_milestones_v170 after insert or update of quantity on public.aamix_collection
for each row execute function aamix_private.collection_milestone_trigger_v170();
create function aamix_private.check_challenge_v170(p_uid uuid) returns void
language plpgsql security definer set search_path='' as $$ begin
 if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=4) then perform aamix_private.complete_milestone_v170(p_uid,'challenge_maagover');end if;
 if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=5) then perform aamix_private.complete_milestone_v170(p_uid,'challenge_girabl');end if;
 if not exists(select 1 from generate_series(1,5) n(stage) where not exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=n.stage)) then
  perform aamix_private.complete_milestone_v170(p_uid,'challenge_complete');
 end if;
end $$;
create function aamix_private.challenge_milestone_trigger_v170() returns trigger
language plpgsql security definer set search_path='' as $$ begin perform aamix_private.check_challenge_v170(new.user_id);return new;end $$;
create trigger challenge_milestones_v170 after insert on public.aamix_challenge_completions for each row execute function aamix_private.challenge_milestone_trigger_v170();

create function aamix_private.milestone_status_v170() returns jsonb
language plpgsql security definer set search_path='' as $$ declare uid uuid:=aamix_private.reward_user(); result jsonb;begin
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'title',d.title,'scope','lifetime','target',10,
  'progress',case when m.completed_at is not null then 10 else least(coalesce(c.quantity,0),10) end,
  'claimed',m.claimed_at is not null,'reward_kind','avatar','reward_amount',1,'reward_code',d.reward_code) order by d.id),'[]') into result
 from aamix_private.milestone_definitions_v170 d left join aamix_private.milestones_v170 m on m.user_id=uid and m.mission_id=d.id
 left join public.aamix_collection c on c.user_id=uid and c.code=d.card_code where not d.secret;
 return result;
end $$;
create function aamix_private.claim_milestone_v170(p_id text) returns jsonb
language plpgsql security definer set search_path='' as $$ declare uid uuid:=aamix_private.lock_rewards(); d aamix_private.milestone_definitions_v170%rowtype;already boolean;begin
 select * into d from aamix_private.milestone_definitions_v170 where id=p_id and not secret;
 if not found then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023';end if;
 if not exists(select 1 from aamix_private.milestones_v170 where user_id=uid and mission_id=p_id) then raise exception 'AAMIX_MISSION_INCOMPLETE' using errcode='22023';end if;
 select claimed_at is not null into already from aamix_private.milestones_v170 where user_id=uid and mission_id=p_id;
 perform aamix_private.grant_milestone_v170(uid,p_id);
 return public.aamix_inventory()||jsonb_build_object('already_claimed',already,'mission_id',p_id,'reward_kind','avatar','reward_amount',1,'reward_code',d.reward_code,'reward_avatar',d.reward_code);
end $$;
create function aamix_private.avatar_allowed_v170(p_uid uuid,p_code text) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from aamix_private.reward_catalog c where c.code=p_code and c.card_class='Aliado'
 and ((not c.is_promotional and c.code not in('0112','0113','0114','0126')) or (c.code in('0112','0113','0114','0126','01a','01b') and exists(select 1 from aamix_private.avatar_unlocks_v170 u where u.user_id=p_uid and u.code=p_code))))
$$;
create function aamix_private.cosmetics_inventory_v170() returns jsonb
language plpgsql security definer set search_path='' as $$ declare uid uuid:=aamix_private.reward_user(); notices jsonb;avatars jsonb;selected text;begin
 select coalesce(jsonb_agg(c.code order by c.code),'[]') into avatars from aamix_private.reward_catalog c where aamix_private.avatar_allowed_v170(uid,c.code);
 select avatar_code into selected from public.aamix_rewards_state where user_id=uid;
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'title',d.title,'kind',d.reward_kind,'code',d.reward_code) order by m.completed_at,d.id),'[]') into notices
 from aamix_private.milestones_v170 m join aamix_private.milestone_definitions_v170 d on d.id=m.mission_id where m.user_id=uid and m.claimed_at is not null and m.acknowledged_at is null;
 return jsonb_build_object('available_avatar_codes',avatars,'profile',jsonb_build_object('avatar_code',case when aamix_private.avatar_allowed_v170(uid,selected) then selected else '' end),'achievement_notifications',notices);
end $$;
create function aamix_private.ack_milestone_v170(p_mission_id text) returns jsonb
language plpgsql security definer set search_path='' as $$ declare uid uuid:=aamix_private.lock_rewards();begin
 update aamix_private.milestones_v170 set acknowledged_at=coalesce(acknowledged_at,now()) where user_id=uid and mission_id=p_mission_id and claimed_at is not null;
 if not found then raise exception 'AAMIX_REWARD_UNAVAILABLE' using errcode='22023';end if;
 return public.aamix_inventory();
end $$;

-- Permanent avatar entitlements from existing gift codes, including earlier redemptions.
alter table aamix_private.gift_code_rewards add column avatar_code text references aamix_private.catalog_codes(code);
update aamix_private.gift_code_rewards set avatar_code=case gift_code when 'B1G0T3S' then '01b' when 'P3RI' then '01a' end where gift_code in('B1G0T3S','P3RI');
insert into aamix_private.avatar_unlocks_v170(user_id,code,source)
select r.user_id,g.avatar_code,r.gift_code from public.aamix_code_redemptions r join aamix_private.gift_code_rewards g on g.gift_code=r.gift_code where g.avatar_code is not null on conflict do nothing;
update public.aamix_rewards_state set avatar_code=null where avatar_code in('0112','0113','0114','0126');

-- Keep completed trades for integrity, but deliver only an own-card notice to1.7.
alter table aamix_private.trade_rooms_v160 add column a_notified boolean not null default false,add column b_notified boolean not null default false;
update aamix_private.trade_rooms_v160 set a_notified=true,b_notified=true where status='completed';
create function aamix_private.trade_notices_v170() returns jsonb
language plpgsql security definer set search_path='' as $$ declare uid uuid:=aamix_private.reward_user();result jsonb;begin
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'code',case when a_id=uid then b_code else a_code end,'drafts',case when a_id=uid then a_drafts else b_drafts end) order by closed_at,id),'[]') into result
 from aamix_private.trade_rooms_v160 r where status='completed' and ((a_id=uid and not a_notified) or (b_id=uid and not b_notified));return result;
end $$;
create function aamix_private.ack_trade_v170(p_room uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$ declare uid uuid:=aamix_private.reward_user();begin
 update aamix_private.trade_rooms_v160 set a_notified=a_notified or a_id=uid,b_notified=b_notified or b_id=uid where id=p_room and uid in(a_id,b_id) and status='completed';
 if not found then raise exception 'AAMIX_TRADE_UNAVAILABLE' using errcode='22023';end if;
 return aamix_private.social_inventory();
end $$;

-- Covers are the existing unified Maagover and Girabl designs, earned by challenge.
do $$ declare c record;begin for c in select conname from pg_constraint where conrelid='public.aamix_custom_decks'::regclass and contype='c' and pg_get_constraintdef(oid) like '%cover%' loop
 execute format('alter table public.aamix_custom_decks drop constraint %I',c.conname);end loop;end $$;
alter table public.aamix_custom_decks add constraint custom_cover_v170 check(cover in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin','custom_kajido','custom_maagover','custom_girabl'));

-- Backfill only provable existing ownership/completions; never reset progress.
do $$ declare u record;c record;begin
 for u in select id from auth.users order by id loop
  perform 1 from public.aamix_rewards_state where user_id=u.id for update;
  for c in select code,quantity from public.aamix_collection where user_id=u.id loop perform aamix_private.check_collection_v170(u.id,c.code,c.quantity);end loop;
  perform aamix_private.check_challenge_v170(u.id);
 end loop;
end $$;

-- GENERATED CONTRACT EXTENSIONS
CREATE OR REPLACE FUNCTION aamix_private.missions_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); today date:=(now() at time zone 'America/Santiago')::date;
  total_finished bigint; total_wins bigint; daily_finished bigint; daily_wins bigint;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select count(*),count(*) filter(where result='victory'),
    count(*) filter(where (finished_at at time zone 'America/Santiago')::date=today),
    count(*) filter(where result='victory' and (finished_at at time zone 'America/Santiago')::date=today)
    into total_finished,total_wins,daily_finished,daily_wins from public.aamix_match_receipts
    where user_id=uid and finished_at is not null and result in('victory','defeat');
  return jsonb_build_array(
    jsonb_build_object('id','play_one','title','Juega 1 partida','scope','daily','day',today,'timezone','America/Santiago',
      'progress',least(daily_finished,1),'target',1,'claimed',exists(select 1 from public.aamix_daily_claims_v016 where user_id=uid and mission_id='play_one' and mission_day=today),
      'reward_kind','restos','reward_amount',25,'reward_packs',0),
    jsonb_build_object('id','win_one','title','Gana 1 partida','scope','daily','day',today,'timezone','America/Santiago',
      'progress',least(daily_wins,1),'target',1,'claimed',exists(select 1 from public.aamix_daily_claims_v016 where user_id=uid and mission_id='win_one' and mission_day=today),
      'reward_kind','normal_pack','reward_amount',1,'reward_packs',0),
    jsonb_build_object('id','play_ten','title','Juega 10 partidas','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_finished,10),'target',10,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='play_ten' and period_key='lifetime'),
      'reward_kind','tc_pack','reward_amount',3,'reward_packs',3),
    jsonb_build_object('id','win_ten','title','Gana 10 partidas','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_wins,10),'target',10,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='win_ten' and period_key='lifetime'),
      'reward_kind','tc_pack','reward_amount',5,'reward_packs',5))||aamix_private.historical_status_v150()||aamix_private.milestone_status_v170();
end $function$
;
CREATE OR REPLACE FUNCTION aamix_private.claim_mission(p_mission_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); today date:=(now() at time zone 'America/Santiago')::date;
  status jsonb; already boolean; amount integer; kind text; receipt_id uuid; granted uuid;
begin
  if p_mission_id in('collect_ten_sam','collect_ten_yuri','collect_ten_celia','collect_ten_viborin') then return aamix_private.claim_milestone_v170(p_mission_id);end if;
  if p_mission_id in('play_fifty','win_fifty','win_five_kajido','win_five_flaan','win_five_papito') then return aamix_private.claim_historical_v150(p_mission_id);end if;
  select m into status from jsonb_array_elements(aamix_private.missions_status()) m where m->>'id'=p_mission_id;
  if not found then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023'; end if;
  already:=(status->>'claimed')::boolean; amount:=(status->>'reward_amount')::integer; kind:=status->>'reward_kind';
  if already and kind='tc_pack' then
    select reward_packs into strict amount from public.aamix_mission_claims where user_id=uid and mission_id=p_mission_id and period_key='lifetime';
  elsif already and p_mission_id in('play_one','win_one') then
    select reward_amount into strict amount from public.aamix_daily_claims_v016 where user_id=uid and mission_id=p_mission_id and mission_day=today;
  end if;
  if not already then
    if (status->>'progress')::integer<(status->>'target')::integer then raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023'; end if;
    perform aamix_private.ensure_restos_welcome();
    if p_mission_id in('play_one','win_one') then
      select match_id into strict receipt_id from public.aamix_match_receipts where user_id=uid and finished_at is not null
        and result in('victory','defeat') and (p_mission_id='play_one' or result='victory')
        and (finished_at at time zone 'America/Santiago')::date=today order by finished_at,match_id limit 1;
      insert into public.aamix_daily_claims_v016(user_id,mission_id,mission_day,completed_match_id,reward_kind,reward_amount)
        values(uid,p_mission_id,today,receipt_id,kind,amount) on conflict(user_id,mission_id,mission_day) do nothing returning user_id into granted;
    else
      insert into public.aamix_mission_claims(user_id,mission_id,period_key,reward_packs) values(uid,p_mission_id,'lifetime',amount)
        on conflict(user_id,mission_id,period_key) do nothing returning user_id into granted;
    end if;
    if granted is not null then
      if kind='restos' then update public.aamix_rewards_state set restos=restos+amount where user_id=uid;
      elsif kind='normal_pack' then update public.aamix_rewards_state set normal_packs=normal_packs+amount where user_id=uid;
      else update public.aamix_rewards_state set packs=packs+amount where user_id=uid; end if;
    else already:=true; end if;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_claimed',already,'mission_id',p_mission_id,
    'reward_kind',kind,'reward_amount',amount,'reward_packs',case when kind='tc_pack' then amount else 0 end);
end $function$
;
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
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'draft',draft,'editable',editable,'revision',revision) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'custom_decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'custom',true,'draft',draft,'revision',revision) order by created_at,deck_id) from public.aamix_custom_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'kind',kind,'cards',cards,'new_card_indices',to_jsonb(new_card_indices),'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb))||aamix_private.deck_designs_inventory()||aamix_private.events_inventory()||aamix_private.cosmetics_inventory_v170();
end $function$
;
CREATE OR REPLACE FUNCTION aamix_private.set_avatar(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := aamix_private.lock_rewards();
begin
  if not aamix_private.avatar_allowed_v170(uid,p_code) then raise exception 'AAMIX_AVATAR_LOCKED' using errcode='22023';end if;
  update public.aamix_rewards_state set avatar_code=p_code where user_id=uid;
  return public.aamix_inventory();
end $function$
;
CREATE OR REPLACE FUNCTION aamix_private.redeem_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid:=aamix_private.lock_rewards(); normalized text:=case upper(btrim(p_code)) when 'B1GOTE5' then 'B1G0T3S' when 'P3R1' then 'P3RI' else upper(btrim(p_code)) end;
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
      'reward_cover',claimed_design,'reward_design',claimed_design,'reward_avatar',configured.avatar_code);
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
  if configured.avatar_code is not null then insert into aamix_private.avatar_unlocks_v170(user_id,code,source) values(uid,configured.avatar_code,normalized) on conflict do nothing;end if;
  return public.aamix_inventory()||jsonb_build_object('already_redeemed',granted is null,'redeemed_code',normalized,
    'reward_name',configured.reward_name,'reward_deck_id',configured.deck_id,'reward_cards',award_cards,
    'reward_packs',configured.packs,'reward_restos',configured.restos,'reward_normal_packs',configured.normal_packs,
    'reward_cover',claimed_design,'reward_design',claimed_design,'reward_avatar',configured.avatar_code);
end $function$
;
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
  from (values('custom_tsuki_akira',1),('custom_chanchuus',2),('custom_viborin',3),('custom_kajido',4),('custom_maagover',5),('custom_girabl',6)) design(id,position)
  where exists(
    select 1 from public.aamix_code_redemptions redeemed
    where redeemed.user_id=uid and redeemed.deck_design=design.id
  ) or exists(select 1 from aamix_private.event_design_unlocks earned where earned.user_id=uid and earned.design=design.id) or exists(select 1 from aamix_private.mission_design_unlocks_v170 m where m.user_id=uid and m.design=design.id);
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
  if normalized_id<>'' and normalized_id not like 'custom_%' then return aamix_private.save_repaired_deck(p_request_id,p_deck_id,p_nombre,p_portada,p_cartas,p_draft,p_expected_revision);end if;
  if p_request_id is null or p_expected_revision is null or p_expected_revision<0 or p_draft is null
    or normalized_name is null or char_length(normalized_name) not between 1 and 48 or normalized_name ~ '[[:cntrl:]]'
    or p_portada is null or p_portada not in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin','custom_kajido','custom_maagover','custom_girabl')
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
  ) and not exists(select 1 from aamix_private.event_design_unlocks earned where earned.user_id=uid and earned.design=p_portada) and not exists(select 1 from aamix_private.mission_design_unlocks_v170 earned where earned.user_id=uid and earned.design=p_portada) then raise exception 'AAMIX_DECK_COVER_LOCKED' using errcode='22023'; end if;
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
CREATE OR REPLACE FUNCTION aamix_private.social_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); code text; friends jsonb; incoming jsonb; outgoing jsonb; trades jsonb; duels jsonb; cards jsonb;
begin
 select friend_code into code from aamix_private.social_people where user_id=uid;
 select coalesce(jsonb_agg(aamix_private.social_peer(case when low_id=uid then high_id else low_id end) order by updated_at),'[]') into friends
 from aamix_private.friendships where uid in(low_id,high_id) and status='accepted';
 select coalesce(jsonb_agg(aamix_private.social_peer(sender) order by updated_at),'[]') into incoming from aamix_private.friendships where uid in(low_id,high_id) and sender<>uid and status='pending';
 select coalesce(jsonb_agg(aamix_private.social_peer(case when low_id=uid then high_id else low_id end) order by updated_at),'[]') into outgoing from aamix_private.friendships where uid in(low_id,high_id) and sender=uid and status='pending';
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'a_id',t.a_id,'b_id',t.b_id,'peer',aamix_private.social_peer(case when a_id=uid then b_id else a_id end),
  'own_code',case when a_id=uid then a_code else b_code end,'peer_code',case when a_id=uid then b_code else a_code end,
  'own_confirmed',case when a_id=uid then a_confirmed else b_confirmed end,'peer_confirmed',case when a_id=uid then b_confirmed else a_confirmed end,
  'revision',revision,'status',case when status='open' and expires_at<=now() then 'expired' else status end,'expires_at',expires_at,
  'drafts',case when a_id=uid then a_drafts else b_drafts end) order by created_at desc),'[]') into trades
 from (select * from aamix_private.card_trades where uid in(a_id,b_id) order by created_at desc limit 100) t;
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'direction',case when d.host_id=uid then 'outgoing' else 'incoming' end,
  'peer',aamix_private.social_peer(case when d.host_id=uid then d.guest_id else d.host_id end),'room_id',d.room_id,'status',d.status,'expires_at',d.expires_at) order by d.created_at),'[]') into duels
 from aamix_private.friend_duels d join aamix_private.mp_rooms r on r.id=d.room_id where uid in(d.host_id,d.guest_id) and d.status='pending' and d.expires_at>now() and r.status='waiting' and aamix_private.social_is_friend(d.host_id,d.guest_id);
 select coalesce(jsonb_agg(jsonb_build_object('code',c.code,'owned',c.quantity,'available',aamix_private.trade_available(uid,c.code),'family',aamix_private.trade_family(c.code)) order by c.code),'[]') into cards
 from public.aamix_collection c where c.user_id=uid and aamix_private.trade_family(c.code) is not null;
 return jsonb_build_object('user_id',uid,'friend_code',code,'friends',friends,'incoming',incoming,'outgoing',outgoing,'trades',trades,'duels',duels,'tradable_cards',cards,'trade_room',aamix_private.trade_room_view_v160(),'trade_notifications',aamix_private.trade_notices_v170());
end $function$
;
revoke all on function aamix_private.grant_milestone_v170(uuid,text) from public,anon,authenticated;
revoke all on function aamix_private.complete_milestone_v170(uuid,text) from public,anon,authenticated;
revoke all on function aamix_private.check_collection_v170(uuid,text,integer) from public,anon,authenticated;
revoke all on function aamix_private.collection_milestone_trigger_v170() from public,anon,authenticated;
revoke all on function aamix_private.check_challenge_v170(uuid) from public,anon,authenticated;
revoke all on function aamix_private.challenge_milestone_trigger_v170() from public,anon,authenticated;
revoke all on function aamix_private.milestone_status_v170() from public,anon,authenticated;
revoke all on function aamix_private.claim_milestone_v170(text) from public,anon,authenticated;
revoke all on function aamix_private.avatar_allowed_v170(uuid,text) from public,anon,authenticated;
revoke all on function aamix_private.cosmetics_inventory_v170() from public,anon,authenticated;
revoke all on function aamix_private.ack_milestone_v170(text) from public,anon,authenticated;
revoke all on function aamix_private.trade_notices_v170() from public,anon,authenticated;
revoke all on function aamix_private.ack_trade_v170(uuid,uuid) from public,anon,authenticated;
grant execute on function aamix_private.milestone_status_v170() to authenticated;
grant execute on function aamix_private.cosmetics_inventory_v170() to authenticated;
grant execute on function aamix_private.ack_milestone_v170(text) to authenticated;
create function public.aamix_ack_achievement(p_mission_id text) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.ack_milestone_v170(p_mission_id) $$;
revoke all on function public.aamix_ack_achievement(text) from public,anon,authenticated;
grant execute on function public.aamix_ack_achievement(text) to authenticated;
grant execute on function aamix_private.ack_trade_v170(uuid,uuid) to authenticated;
create function public.aamix_ack_trade(p_room uuid,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.ack_trade_v170(p_room,p_request_id) $$;
revoke all on function public.aamix_ack_trade(uuid,uuid) from public,anon,authenticated;
grant execute on function public.aamix_ack_trade(uuid,uuid) to authenticated;
notify pgrst,'reload schema';
