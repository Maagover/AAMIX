-- Additive historical mission expansion, with existing progress retained.
create table aamix_private.historical_claims_v150(user_id uuid not null references auth.users(id) on delete cascade,mission_id text not null check(mission_id in('play_fifty','win_fifty','win_five_kajido','win_five_flaan','win_five_papito')),reward_kind text not null,reward_amount integer not null check(reward_amount>0),claimed_at timestamptz not null default now(),primary key(user_id,mission_id));
alter table aamix_private.historical_claims_v150 enable row level security;
create policy historical_server on aamix_private.historical_claims_v150 for all to anon,authenticated using(false) with check(false);
revoke all on aamix_private.historical_claims_v150 from public,anon,authenticated;
create function aamix_private.historical_status_v150() returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user();q record;progress bigint;result jsonb:='[]';
begin
 for q in select * from (values
('play_fifty','Juega 50 partidas',50,'normal_pack',10,null::text),
('win_fifty','Gana 50 partidas',50,'tc_pack',7,null::text),
('win_five_kajido','Gana 5 partidas con un mazo que incluya a Kajido',5,'restos',200,'0105'),
('win_five_flaan','Gana 5 partidas con un mazo que incluya a SoyFlaan',5,'restos',200,'0103'),
('win_five_papito','Gana 5 partidas con un mazo que incluya a Papito',5,'restos',200,'0115')
 ) definitions(id,title,target,kind,amount,card) loop
  select count(*) into progress from public.aamix_match_receipts r where r.user_id=uid and r.finished_at is not null and r.result in('victory','defeat')
  and (q.id='play_fifty' or r.result='victory') and (q.card is null or exists(select 1 from jsonb_array_elements(coalesce(r.player_deck->'cartas','[]')) c where c->>'codigo'=q.card and (c->>'cantidad')::integer>0));
  result:=result||jsonb_build_array(jsonb_build_object('id',q.id,'title',q.title,'scope','lifetime','target',q.target,'progress',least(progress,q.target),'claimed',exists(select 1 from aamix_private.historical_claims_v150 where user_id=uid and mission_id=q.id),'reward_kind',q.kind,'reward_amount',q.amount,'reward_packs',case when q.kind='tc_pack' then q.amount else 0 end));
 end loop;
 return result;
end $$;
revoke all on function aamix_private.historical_status_v150() from public,anon,authenticated;
grant execute on function aamix_private.historical_status_v150() to authenticated;
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
      'reward_kind','tc_pack','reward_amount',5,'reward_packs',5))||aamix_private.historical_status_v150();
end $function$
;

create function aamix_private.claim_historical_v150(p_mission text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards();s jsonb;r aamix_private.historical_claims_v150%rowtype;already boolean;
begin
 select value into s from jsonb_array_elements(aamix_private.historical_status_v150()) where value->>'id'=p_mission;
 if s is null then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023';end if;
 select * into r from aamix_private.historical_claims_v150 where user_id=uid and mission_id=p_mission;already:=found;
 if not already then
  if (s->>'progress')::integer<(s->>'target')::integer then raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023';end if;
  perform aamix_private.ensure_restos_welcome();
  insert into aamix_private.historical_claims_v150(user_id,mission_id,reward_kind,reward_amount) values(uid,p_mission,s->>'reward_kind',(s->>'reward_amount')::integer) returning * into r;
  update public.aamix_rewards_state set restos=restos+case when r.reward_kind='restos' then r.reward_amount else 0 end,
   packs=packs+case when r.reward_kind='tc_pack' then r.reward_amount else 0 end,normal_packs=normal_packs+case when r.reward_kind='normal_pack' then r.reward_amount else 0 end where user_id=uid;
 end if;
 return public.aamix_inventory()||jsonb_build_object('already_claimed',already,'mission_id',p_mission,'reward_kind',r.reward_kind,'reward_amount',r.reward_amount,'reward_packs',case when r.reward_kind='tc_pack' then r.reward_amount else 0 end);
end $$;
revoke all on function aamix_private.claim_historical_v150(text) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION aamix_private.claim_mission(p_mission_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); today date:=(now() at time zone 'America/Santiago')::date;
  status jsonb; already boolean; amount integer; kind text; receipt_id uuid; granted uuid;
begin
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
notify pgrst,'reload schema';
