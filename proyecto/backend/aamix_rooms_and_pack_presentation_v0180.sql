-- AAMIX 0.18.0. Additive migration; existing balances, openings and receipts preserved.
-- 50 remains valid for historical daily claims; new claims are awarded 25.
alter table public.aamix_daily_claims_v016 drop constraint aamix_daily_claims_v016_check;
alter table public.aamix_daily_claims_v016 add constraint aamix_daily_claims_v016_check check(
  (mission_id='play_one' and reward_kind='restos' and reward_amount in(25,50)) or
  (mission_id='win_one' and reward_kind='normal_pack' and reward_amount=1));
alter table public.aamix_pack_openings add column new_card_indices integer[] not null default '{}';
alter table public.aamix_pack_openings add constraint aamix_opening_new_indices check(new_card_indices <@ array[0,1,2,3,4]);
alter table aamix_private.mp_rooms add column host_confirmed boolean not null default false,
  add column guest_confirmed boolean not null default false;
-- Already-running rooms retain their start state; no existing room is restarted.
update aamix_private.mp_rooms set host_confirmed=true,guest_confirmed=true where started_at is not null;
create or replace function aamix_private.missions_status() returns jsonb
language plpgsql security invoker set search_path='' as $$
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
      'reward_kind','tc_pack','reward_amount',5,'reward_packs',5));
end $$;

create or replace function aamix_private.claim_mission(p_mission_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); today date:=(now() at time zone 'America/Santiago')::date;
  status jsonb; already boolean; amount integer; kind text; receipt_id uuid; granted uuid;
begin
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
end $$;

create or replace function public.aamix_inventory() returns jsonb
language plpgsql security invoker set search_path='' as $$
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
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'kind',kind,'cards',cards,'new_card_indices',to_jsonb(new_card_indices),'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb));
end $$;

create or replace function aamix_private.open_pack_kind(p_request_id uuid,p_kind text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); opening public.aamix_pack_openings%rowtype; inventory jsonb;
begin
  if p_request_id is null then raise exception 'Opening request UUID required' using errcode='22023'; end if;
  if p_kind is null or p_kind not in('tc','normal_card') then raise exception 'Invalid pack kind' using errcode='22023'; end if;
  select o.* into opening from public.aamix_pack_requests r join public.aamix_pack_openings o on o.opening_id=r.opening_id
    where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
  if not found then
    -- One shared pending animation across both kinds. Resuming never spends again.
    select * into opening from public.aamix_pack_openings where user_id=uid and revealed_at is null;
    if not found then
      if p_kind='tc' then
        update public.aamix_rewards_state set packs=packs-1 where user_id=uid and packs>0;
      else
        update public.aamix_rewards_state set normal_packs=normal_packs-1 where user_id=uid and normal_packs>0;
      end if;
      if not found then raise exception 'AAMIX_NO_PACKS' using errcode='22023'; end if;
      insert into public.aamix_pack_openings(user_id,request_id,kind,cards,rules_version)
        values(uid,p_request_id,p_kind,case when p_kind='tc' then aamix_private.draw_pack() else aamix_private.draw_normal_card() end,
          case when p_kind='tc' then '0.10.1' else '0.16.0' end) returning * into opening;
      -- Compute against pre-award quantities. Only the first duplicate in this
      -- opening is new; the result persists across retries and later logins.
      update public.aamix_pack_openings set new_card_indices=coalesce((
        select array_agg((c.ord-1)::integer order by c.ord)
        from jsonb_array_elements_text(opening.cards) with ordinality c(code,ord)
        where not exists(select 1 from public.aamix_collection owned where owned.user_id=uid and owned.code=c.code and owned.quantity>0)
          and c.ord=(select min(x.ord) from jsonb_array_elements_text(opening.cards) with ordinality x(code,ord) where x.code=c.code)
      ),'{}'::integer[]) where opening_id=opening.opening_id returning * into opening;
      insert into public.aamix_collection(user_id,code,quantity)
        select uid,code,count(*)::integer from jsonb_array_elements_text(opening.cards) as card(code) group by code order by code
        on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    end if;
  end if;
  insert into public.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict(user_id,request_id) do nothing;
  inventory:=public.aamix_inventory();
  return inventory||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,
    'cards',opening.cards,'new_card_indices',to_jsonb(opening.new_card_indices),'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end $$;

create or replace function aamix_private.mp_response(p_room_id uuid,p_uid uuid,p_since integer default -1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r aamix_private.mp_rooms%rowtype; s integer; data jsonb;
begin
  select * into strict r from aamix_private.mp_rooms where id=p_room_id;
  s:=case when p_uid=r.host_id then 0 when p_uid=r.guest_id then 1 else -1 end;
  if s=-1 then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  data:=jsonb_build_object('protocol',2,'confirmed',jsonb_build_array(r.host_confirmed,r.guest_confirmed),'room_id',r.id,'code',r.code,'status',r.status,'slot',s,'revision',r.revision,
    'actor_slot',r.actor_slot,'winner',r.winner,'expires_at',r.expires_at,'last_error',r.last_error,
    'finish_reason',r.finish_reason,'opponent_online',case when s=0 then r.guest_seen>now()-interval '20 seconds' else r.host_seen>now()-interval '20 seconds' end,
    'players',jsonb_build_array(
      jsonb_build_object('slot',0,'name',r.host_name,'deck_id',r.host_deck->>'id','deck_name',r.host_deck->>'nombre','cover',r.host_deck->>'portada'),
      case when r.guest_id is null then null else jsonb_build_object('slot',1,'name',r.guest_name,'deck_id',r.guest_deck->>'id','deck_name',r.guest_deck->>'nombre','cover',r.guest_deck->>'portada') end));
  if s=0 then
    data:=data||jsonb_build_object('commands',coalesce((
      select jsonb_agg(jsonb_build_object('request_id',c.request_id,'slot',c.slot,'method',c.method,'args',c.args,'revision',c.revision) order by c.created_at)
      from aamix_private.mp_commands c where c.room_id=r.id and c.status='pending'),'[]'::jsonb));
    if r.revision=0 or p_since=-1 then
      data:=data||jsonb_build_object('host_deck',r.host_deck,'guest_deck',r.guest_deck);
      data:=jsonb_set(data,'{players,0,deck}',r.host_deck);
    if r.guest_id is not null then data:=jsonb_set(data,'{players,1,deck}',r.guest_deck); end if;
    end if;
  end if;
  if p_since<>r.revision then data:=data||jsonb_build_object('state',case s when 0 then r.host_state else r.guest_view end); end if;
  return data;
end $$;

create or replace function aamix_private.mp_commit(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; c aamix_private.mp_commands%rowtype;
  digest text:=md5(jsonb_build_array(p_expected_revision,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error)::text);
begin
  if p_request_id is null or p_expected_revision is null or p_error is null or p_error not in('','AAMIX_INVALID_ACTION') then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023'; end if;
  select * into r from aamix_private.mp_rooms where id=p_room_id for update;
  if not found or uid<>r.host_id then raise exception 'AAMIX_HOST_REQUIRED' using errcode='42501'; end if;
  if r.initial_request=p_request_id then
    if r.initial_digest is distinct from digest then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid);
  end if;
  select * into c from aamix_private.mp_commands where room_id=r.id and request_id=p_request_id;
  if found and c.status<>'pending' then
    if c.commit_digest is distinct from digest then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid);
  end if;
  if r.revision<>p_expected_revision then raise exception 'AAMIX_STALE_REVISION' using errcode='40001'; end if;
  if r.expires_at<now() then raise exception 'AAMIX_ROOM_EXPIRED' using errcode='22023'; end if;
  if r.status='ready' and r.host_state is null then
    if not r.host_confirmed or not r.guest_confirmed then raise exception 'AAMIX_CONFIRM_REQUIRED' using errcode='22023'; end if;
    if p_error<>'' or p_winner<>-1 or r.guest_id is null then raise exception 'AAMIX_INVALID_SNAPSHOT' using errcode='22023'; end if;
  elsif r.status='playing' and c.status='pending' and c.revision=r.revision then
    if p_error<>'' and (p_host_state is distinct from r.host_state or p_guest_view is distinct from r.guest_view or p_actor_slot<>r.actor_slot or p_winner<>-1) then
      raise exception 'AAMIX_REJECTION_CHANGED_STATE' using errcode='22023';
    end if;
  else raise exception 'AAMIX_UNKNOWN_COMMAND' using errcode='22023'; end if;
  perform aamix_private.mp_validate_views(p_host_state,p_guest_view,p_actor_slot,p_winner);
  if r.status='ready' then
    update aamix_private.mp_rooms set initial_request=p_request_id,initial_digest=digest,started_at=now(),status='playing' where id=r.id;
  else
    update aamix_private.mp_commands set status=case when p_error='' then 'committed' else 'rejected' end,commit_digest=digest where room_id=r.id and request_id=p_request_id;
  end if;
  update aamix_private.mp_rooms set host_state=p_host_state,guest_view=p_guest_view,actor_slot=p_actor_slot,winner=p_winner,
    revision=revision+1,host_seen=now(),last_error=p_error where id=r.id;
  if p_winner in(0,1) then perform aamix_private.mp_finish(r.id,p_winner,'completed'); end if;
  return aamix_private.mp_response(r.id,uid);
end $$;

create function aamix_private.mp_confirm(p_room_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype;
begin
  select * into r from aamix_private.mp_rooms where id=p_room_id for update;
  if not found or uid not in(r.host_id,coalesce(r.guest_id,r.host_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  if r.expires_at<now() or r.status not in('waiting','ready','playing') then raise exception 'AAMIX_ROOM_EXPIRED' using errcode='22023'; end if;
  update aamix_private.mp_rooms set host_confirmed=host_confirmed or uid=host_id,
    guest_confirmed=guest_confirmed or (guest_id is not null and uid=guest_id),
    host_seen=case when uid=host_id then now() else host_seen end,
    guest_seen=case when uid=guest_id then now() else guest_seen end where id=r.id;
  return aamix_private.mp_response(r.id,uid);
end $$;
create function public.aamix_mp_confirm(p_room_id uuid) returns jsonb
language sql security invoker set search_path='' as $$select aamix_private.mp_confirm(p_room_id);$$;

-- The creator still uses the same checked command/revision gate, but its own
-- submit and commit share one atomic RPC instead of two network round trips.
create function aamix_private.mp_host_action(p_room_id uuid,p_request_id uuid,p_expected_revision integer,
 p_method text,p_args jsonb,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype;
begin
  select * into r from aamix_private.mp_rooms where id=p_room_id for update;
  if not found or uid<>r.host_id then raise exception 'AAMIX_HOST_REQUIRED' using errcode='42501'; end if;
  perform aamix_private.mp_submit(p_room_id,p_request_id,p_expected_revision,p_method,p_args);
  return aamix_private.mp_commit(p_room_id,p_request_id,p_expected_revision,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);
end $$;
create function public.aamix_mp_host_action(p_room_id uuid,p_request_id uuid,p_expected_revision integer,
 p_method text,p_args jsonb,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
language sql security invoker set search_path='' as $$select aamix_private.mp_host_action(p_room_id,p_request_id,p_expected_revision,p_method,p_args,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);$$;

revoke all on function aamix_private.mp_confirm(uuid),public.aamix_mp_confirm(uuid),
 aamix_private.mp_host_action(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text),
 public.aamix_mp_host_action(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text) from public,anon,authenticated;
grant execute on function aamix_private.mp_confirm(uuid),public.aamix_mp_confirm(uuid),
 aamix_private.mp_host_action(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text),
 public.aamix_mp_host_action(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text) to authenticated;
notify pgrst,'reload schema';
