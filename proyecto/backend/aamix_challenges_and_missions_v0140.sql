-- AAMIX 0.14.0. Additive schema after aamix_missions_and_gifts_v0120.
-- Prepared source for review; migration identity is assigned by Supabase.
-- Auth/SMTP, existing receipts, redemptions, claims and pack odds are preserved.
-- Local AI outcomes remain client-reported; this is not authoritative game simulation.

-- Keep every historic dated WIN1 claim. Any such row blocks its new lifetime reward.
alter table public.aamix_mission_claims drop constraint aamix_mission_claims_mission_id_check;
alter table public.aamix_mission_claims drop constraint aamix_mission_claims_check;
alter table public.aamix_mission_claims add constraint aamix_mission_claim_ids
  check(mission_id in('win_one','play_ten','win_ten'));
alter table public.aamix_mission_claims add constraint aamix_mission_claim_period
  check((mission_id in('play_ten','win_ten') and period_key='lifetime') or
        (mission_id='win_one' and (period_key='lifetime' or period_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')));
-- The previous release paid PLAY10 five packs. Record those paid amounts without
-- changing any balance, date or claim key; new PLAY10 claims pay three packs.
alter table public.aamix_mission_claims add column reward_packs integer;
update public.aamix_mission_claims set reward_packs=case mission_id when 'play_ten' then 5 else 1 end;
alter table public.aamix_mission_claims alter column reward_packs set not null;
alter table public.aamix_mission_claims add constraint aamix_mission_claim_amount check(reward_packs>0);

-- The receipt captures its stage and exact opponent at start. Finish never takes a stage.
alter table public.aamix_match_receipts add column challenge_stage smallint check(challenge_stage between 1 and 5);
alter table public.aamix_match_receipts add column challenge_opponent jsonb;
alter table public.aamix_match_receipts add constraint aamix_challenge_receipt_shape check(
  (challenge_stage is null and challenge_opponent is null) or
  coalesce((challenge_stage is not null and challenge_opponent is not null and
   jsonb_typeof(challenge_opponent)='object' and
   challenge_opponent->>'id'=case challenge_stage when 1 then 'papito' when 2 then 'flaan' when 3 then 'kajido' when 4 then 'maago' when 5 then 'girabl' end and
   jsonb_typeof(challenge_opponent->'cartas')='array'),false));
create table public.aamix_challenge_completions (
  user_id uuid not null references auth.users(id) on delete cascade,
  stage smallint not null check(stage between 1 and 5),
  winning_match_id uuid not null unique references public.aamix_match_receipts(match_id),
  completed_at timestamptz not null default now(),
  reward_packs integer not null,
  primary key(user_id,stage),
  check(reward_packs=case stage when 1 then 1 when 2 then 1 when 3 then 1 when 4 then 2 when 5 then 3 end)
);
alter table public.aamix_challenge_completions enable row level security;
revoke all on public.aamix_challenge_completions from public,anon,authenticated;
grant select on public.aamix_challenge_completions to authenticated;
create policy challenge_completions_owner_read on public.aamix_challenge_completions for select to authenticated
  using((select auth.uid())=user_id);

-- Public definitions contain no player data, secrets or mutating privileges.
create function aamix_private.challenge_definitions() returns jsonb
language sql immutable security invoker set search_path='' as $$
  select '[{"stage":1,"deck_id":"papito","title":"Mazo Papito","reward_packs":1},{"stage":2,"deck_id":"flaan","title":"Mazo Flaan","reward_packs":1},{"stage":3,"deck_id":"kajido","title":"Mazo Kajido","reward_packs":1},{"stage":4,"deck_id":"maago","title":"Mazo Maagover","reward_packs":2},{"stage":5,"deck_id":"girabl","title":"Mazo Girabl","reward_packs":3}]'::jsonb;
$$;
revoke all on function aamix_private.challenge_definitions() from public,anon,authenticated;
grant execute on function aamix_private.challenge_definitions() to authenticated;
create function aamix_private.challenges_status() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); status jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select jsonb_agg(d || jsonb_build_object(
    'unlocked',not exists(select 1 from generate_series(1,(d->>'stage')::integer-1) previous(stage)
      where not exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)),
    'completed',exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer),
    'reward_claimed',exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer)
  ) order by (d->>'stage')::integer) into status from jsonb_array_elements(aamix_private.challenge_definitions()) d;
  return status;
end $$;
revoke all on function aamix_private.challenges_status() from public,anon,authenticated;
grant execute on function aamix_private.challenges_status() to authenticated;

create or replace function aamix_private.missions_status() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); today date:=(now() at time zone 'America/Santiago')::date;
  total_finished bigint; total_wins bigint; daily_finished bigint; play_one jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select count(*),count(*) filter(where result='victory'),
    count(*) filter(where (finished_at at time zone 'America/Santiago')::date=today)
    into total_finished,total_wins,daily_finished from public.aamix_match_receipts
    where user_id=uid and finished_at is not null and result in('victory','defeat');
  play_one:=jsonb_build_object('id','play_one','title','Juega 1 partida','day',today,'timezone','America/Santiago',
    'progress',case when daily_finished>0 or exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today) then 1 else 0 end,
    'target',1,'claimed',exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today and claimed_at is not null),'reward_packs',1);
  return jsonb_build_array(play_one||jsonb_build_object('scope','daily'),
    jsonb_build_object('id','win_one','title','Gana 1 partida','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_wins,1),'target',1,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='win_one'),'reward_packs',1),
    jsonb_build_object('id','play_ten','title','Juega 10 partidas','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_finished,10),'target',10,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='play_ten' and period_key='lifetime'),'reward_packs',3),
    jsonb_build_object('id','win_ten','title','Gana 10 partidas','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_wins,10),'target',10,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='win_ten' and period_key='lifetime'),'reward_packs',5));
end $$;

create or replace function public.aamix_inventory() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); missions jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  missions:=aamix_private.missions_status();
  return jsonb_build_object(
    'user_id',uid,
    'gift',(select jsonb_build_object('deck_id',deck_id,'awarded_at',awarded_at) from public.aamix_starter_gifts where user_id=uid),
    'collection',coalesce((select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=uid),'{}'::jsonb),
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'cards',cards,'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb));
end $$;

create or replace function aamix_private.claim_mission(p_mission_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); today date:=(now() at time zone 'America/Santiago')::date;
  status jsonb; already boolean; prize integer; receipt_id uuid; granted uuid;
begin
  select m into status from jsonb_array_elements(aamix_private.missions_status()) m where m->>'id'=p_mission_id;
  if not found then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023'; end if;
  already:=(status->>'claimed')::boolean; prize:=(status->>'reward_packs')::integer;
  if already and p_mission_id<>'play_one' then
    select reward_packs into strict prize from public.aamix_mission_claims where user_id=uid and mission_id=p_mission_id
      order by claimed_at,period_key limit 1;
  end if;
  if not already then
    if (status->>'progress')::integer<(status->>'target')::integer then raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023'; end if;
    if p_mission_id='play_one' then
      if not exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today) then
        select match_id into strict receipt_id from public.aamix_match_receipts where user_id=uid and finished_at is not null and result in('victory','defeat')
          and (finished_at at time zone 'America/Santiago')::date=today order by finished_at,match_id limit 1;
        insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id,completed_at)
          select uid,today,match_id,finished_at from public.aamix_match_receipts where user_id=uid and match_id=receipt_id;
      end if;
      update public.aamix_daily_missions set claimed_at=now() where user_id=uid and mission_day=today and claimed_at is null returning user_id into granted;
    else
      insert into public.aamix_mission_claims(user_id,mission_id,period_key,reward_packs) values(uid,p_mission_id,'lifetime',prize)
        on conflict(user_id,mission_id,period_key) do nothing returning user_id into granted;
    end if;
    if granted is not null then update public.aamix_rewards_state set packs=packs+prize where user_id=uid;
    else already:=true; end if;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_claimed',already,'mission_id',p_mission_id,'reward_packs',prize);
end $$;

-- Preserve old random RPC and make a UUID unusable across random/challenge modes.
create or replace function aamix_private.begin_match(p_request_id uuid,p_deck_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  if not exists(select 1 from public.aamix_owned_decks where user_id=uid and deck_id=p_deck_id) then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found and (receipt.deck_id<>p_deck_id or receipt.challenge_stage is not null) then raise exception 'Request UUID already used for a different match' using errcode='22023'; end if;
  if not found then insert into public.aamix_match_receipts(user_id,request_id,deck_id) values(uid,p_request_id,p_deck_id) returning * into receipt; end if;
  return public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result,'challenge_stage',null);
end $$;

create function aamix_private.begin_challenge_match(p_request_id uuid,p_deck_id text,p_stage integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype;
  definition jsonb; opponent jsonb;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  select d into definition from jsonb_array_elements(aamix_private.challenge_definitions()) d where (d->>'stage')::integer=p_stage;
  if not found then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;
  if not exists(select 1 from public.aamix_owned_decks where user_id=uid and deck_id=p_deck_id) then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found then
    if receipt.deck_id<>p_deck_id or receipt.challenge_stage is distinct from p_stage then raise exception 'Request UUID already used for a different match' using errcode='22023'; end if;
  else
    if exists(select 1 from generate_series(1,p_stage-1) previous(stage) where not exists(
      select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then
      raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023';
    end if;
    select jsonb_build_object('id',id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) into strict opponent
      from aamix_private.base_decks where id=definition->>'deck_id';
    insert into public.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent)
      values(uid,p_request_id,p_deck_id,p_stage,opponent) returning * into receipt;
  end if;
  return public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result,
    'challenge_stage',receipt.challenge_stage,'challenge_opponent',receipt.challenge_opponent);
end $$;
revoke all on function aamix_private.begin_challenge_match(uuid,text,integer) from public,anon,authenticated;
grant execute on function aamix_private.begin_challenge_match(uuid,text,integer) to authenticated;
create function public.aamix_begin_challenge_match(p_request_id uuid,p_deck_id text,p_stage integer) returns jsonb
language sql security invoker set search_path='' as $$ select aamix_private.begin_challenge_match(p_request_id,p_deck_id,p_stage); $$;
revoke all on function public.aamix_begin_challenge_match(uuid,text,integer) from public,anon,authenticated;
grant execute on function public.aamix_begin_challenge_match(uuid,text,integer) to authenticated;

create or replace function aamix_private.finish_match(p_match_id uuid,p_result text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype;
  today date:=(now() at time zone 'America/Santiago')::date; definition jsonb; granted integer;
  prize integer:=0; already_completed boolean:=false;
begin
  if p_result is null or p_result not in('victory','defeat') then raise exception 'Completed victory or defeat required' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and match_id=p_match_id for update;
  if not found then raise exception 'Unknown match receipt' using errcode='22023'; end if;
  if receipt.challenge_stage is not null then
    select d into strict definition from jsonb_array_elements(aamix_private.challenge_definitions()) d where (d->>'stage')::integer=receipt.challenge_stage;
    if receipt.challenge_opponent->>'id' is distinct from definition->>'deck_id' then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;
    already_completed:=exists(select 1 from public.aamix_challenge_completions where user_id=uid and stage=receipt.challenge_stage);
  end if;
  if receipt.result is null then
    if receipt.challenge_stage is not null and exists(select 1 from generate_series(1,receipt.challenge_stage-1) previous(stage)
      where not exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then
      raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023';
    end if;
    update public.aamix_match_receipts set finished_at=now(),result=p_result where match_id=receipt.match_id;
    insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id) values(uid,today,receipt.match_id) on conflict(user_id,mission_day) do nothing;
    if receipt.challenge_stage is not null and p_result='victory' then
      insert into public.aamix_challenge_completions(user_id,stage,winning_match_id,reward_packs)
        values(uid,receipt.challenge_stage,receipt.match_id,(definition->>'reward_packs')::integer)
        on conflict(user_id,stage) do nothing returning stage into granted;
      if granted is not null then
        prize:=(definition->>'reward_packs')::integer;
        update public.aamix_rewards_state set packs=packs+prize where user_id=uid;
      end if;
    end if;
  elsif receipt.result<>p_result then raise exception 'Match already finished with another result' using errcode='22023'; end if;
  return public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',p_result,
    'challenge_stage',receipt.challenge_stage,'challenge_reward_packs',prize,'challenge_already_completed',already_completed);
end $$;

-- Replaced functions retain existing privileges; assert no public accidental grants.
revoke all on function aamix_private.missions_status(),aamix_private.claim_mission(text),aamix_private.begin_match(uuid,text),aamix_private.finish_match(uuid,text),public.aamix_inventory() from public,anon,authenticated;
grant execute on function aamix_private.missions_status(),aamix_private.claim_mission(text),aamix_private.begin_match(uuid,text),aamix_private.finish_match(uuid,text),public.aamix_inventory() to authenticated;
notify pgrst,'reload schema';
