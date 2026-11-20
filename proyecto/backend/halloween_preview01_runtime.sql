-- Server-authoritative preview only. No statement below writes any stable AAMIX table.
create function aamix_hw01_private.bootstrap() returns void language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();fresh uuid;
begin
 insert into aamix_hw01_private.hw_wallet(user_id) values(uid) on conflict do nothing returning user_id into fresh;
 if fresh is null then return;end if;
 insert into aamix_hw01.aamix_rewards_state(user_id,restos,packs,normal_packs,avatar_code) values(uid,5000,3,3,'0108') on conflict(user_id) do nothing;
 insert into aamix_hw01.aamix_restos_welcome(user_id,amount) values(uid,100) on conflict do nothing;
 insert into aamix_hw01.aamix_welcome_packs(user_id,packs,challenge_entered_at) values(uid,1,now()) on conflict do nothing;
 insert into aamix_hw01.aamix_starter_gifts(user_id,deck_id) values(uid,'papito') on conflict do nothing;
 insert into aamix_hw01.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select uid,id,name,cover,cards from aamix_hw01_private.base_decks on conflict do nothing;
 insert into aamix_hw01.aamix_collection(user_id,code,quantity)
  select uid,code,case when card_class='Recurso' then 80 when is_singular then 1 else 3 end
  from aamix_hw01_private.reward_catalog where code not like 'H%' on conflict do nothing;
 update aamix_hw01_private.milestones_v170 set acknowledged_at=now() where user_id=uid and claimed_at is not null;
end $$;

create function aamix_hw01_private.halloween_progress() returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();earned integer;played integer;wins integer;event_wins integer;friend_added boolean;traded boolean;
begin
 perform 1 from aamix_hw01_private.hw_wallet where user_id=uid for update;
 with granted as(
  insert into aamix_hw01_private.hw_mp_rewards(user_id,match_id)
  select uid,r.match_id from aamix_hw01.aamix_match_receipts r where r.user_id=uid and r.online_room_id is not null and r.result='victory'
  on conflict do nothing returning match_id
 )select count(*) into earned from granted;
 if earned>0 then update aamix_hw01_private.hw_wallet set halloween_packs=halloween_packs+earned where user_id=uid;end if;
 update aamix_hw01_private.hw_wallet set
  friend_added=hw_wallet.friend_added or exists(select 1 from aamix_hw01_private.friendships f where uid in(f.low_id,f.high_id) and f.status='accepted'),
  traded=hw_wallet.traded or exists(select 1 from aamix_hw01_private.trade_rooms_v160 t where uid in(t.a_id,t.b_id) and t.status='completed')
  where user_id=uid returning hw_wallet.friend_added,hw_wallet.traded into friend_added,traded;
 select count(*)filter(where result in('victory','defeat')),count(*)filter(where result='victory'),count(*)filter(where result='victory' and event_battle)
  into played,wins,event_wins from aamix_hw01.aamix_match_receipts where user_id=uid;
 return jsonb_build_object('played',played,'wins',wins,'event_wins',event_wins,'friends',case when friend_added then 1 else 0 end,'trades',case when traded then 1 else 0 end);
end $$;

create or replace function aamix_hw01_private.events_inventory() returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();e jsonb:=aamix_hw01_private.halloween_definition();m jsonb;progress jsonb;states jsonb:='[]';
begin
 progress:=aamix_hw01_private.halloween_progress();
 for m in select value from jsonb_array_elements(e->'missions') loop
  states:=states||jsonb_build_array(m||jsonb_build_object('progress',least(coalesce((progress->>(m->>'metric'))::integer,0),(m->>'target')::integer),
   'claimed',exists(select 1 from aamix_hw01_private.event_claims c where c.user_id=uid and c.event_id='halloween_2026' and c.mission_id=m->>'id' and c.period_key='once')));
 end loop;
 return jsonb_build_object('server_time',extract(epoch from now()),'server_day',(now() at time zone 'America/Santiago')::date,
  'events_valid_until',extract(epoch from now()+interval '1 hour'),'events',jsonb_build_array(e||jsonb_build_object('missions',states)),
  'halloween_packs',coalesce((select halloween_packs from aamix_hw01_private.hw_wallet where user_id=uid),0),'preview',true);
end $$;

create or replace function aamix_hw01_private.claim_event_mission(p_event_id text,p_mission_id text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.lock_rewards();status jsonb;m jsonb;reward jsonb;already boolean;card jsonb;
begin
 if p_event_id is distinct from 'halloween_2026' then raise exception 'AAMIX_EVENT_INACTIVE' using errcode='22023';end if;
 status:=aamix_hw01_private.events_inventory();
 select value into m from jsonb_array_elements(status->'events'->0->'missions') where value->>'id'=p_mission_id;
 if m is null then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023';end if;
 already:=(m->>'claimed')::boolean;reward:=m->'reward';
 if not already then
  if(m->>'progress')::integer<(m->>'target')::integer then raise exception 'AAMIX_MISSION_INCOMPLETE' using errcode='22023';end if;
  insert into aamix_hw01_private.event_claims(user_id,event_id,mission_id,period_key,reward) values(uid,p_event_id,p_mission_id,'once',reward);
  update aamix_hw01_private.hw_wallet set halloween_packs=halloween_packs+coalesce((reward->>'halloween_packs')::integer,0) where user_id=uid;
  for card in select value from jsonb_array_elements(coalesce(reward->'cards','[]')) loop
   insert into aamix_hw01.aamix_collection(user_id,code,quantity) values(uid,card->>'codigo',(card->>'cantidad')::integer)
   on conflict(user_id,code) do update set quantity=aamix_hw01.aamix_collection.quantity+excluded.quantity;
  end loop;
 end if;
 return aamix_hw01.aamix_inventory()||jsonb_build_object('already_claimed',already,'event_reward',reward);
end $$;

create function aamix_hw01_private.open_halloween_pack(p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.lock_rewards();opening aamix_hw01.aamix_pack_openings%rowtype;ticket integer;picked_code text;first_copy boolean;
begin
 if p_request_id is null then raise exception 'Opening request UUID required' using errcode='22023';end if;
 select o.* into opening from aamix_hw01.aamix_pack_requests r join aamix_hw01.aamix_pack_openings o on o.opening_id=r.opening_id where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
 if not found then
  select * into opening from aamix_hw01.aamix_pack_openings where user_id=uid and revealed_at is null;
  if not found then
   update aamix_hw01_private.hw_wallet set halloween_packs=halloween_packs-1 where user_id=uid and halloween_packs>0;
   if not found then raise exception 'AAMIX_NO_PACKS' using errcode='22023';end if;
   ticket:=floor(random()*10000)::integer;
   picked_code:=case when ticket>=9500 then 'H05' else 'H0'||(ticket/2375+1)::text end;
   first_copy:=not exists(select 1 from aamix_hw01.aamix_collection c where c.user_id=uid and c.code=picked_code and quantity>0);
   insert into aamix_hw01.aamix_pack_openings(user_id,request_id,kind,cards,rules_version,new_card_indices)
    values(uid,p_request_id,'halloween',jsonb_build_array(picked_code),'halloween-preview1',case when first_copy then array[0] else '{}'::integer[] end) returning * into opening;
   insert into aamix_hw01.aamix_collection(user_id,code,quantity) values(uid,picked_code,1) on conflict(user_id,code) do update set quantity=aamix_hw01.aamix_collection.quantity+1;
  end if;
 end if;
 insert into aamix_hw01.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict do nothing;
 return aamix_hw01.aamix_inventory()||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,'cards',opening.cards,'new_card_indices',to_jsonb(opening.new_card_indices),'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end $$;
create function aamix_hw01.aamix_open_halloween_pack(p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select aamix_hw01_private.open_halloween_pack(p_request_id)$$;

create function aamix_hw01_private.begin_event_match(p_request_id uuid,p_deck_id text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.lock_rewards();receipt aamix_hw01.aamix_match_receipts%rowtype;response jsonb;
begin
 if p_request_id is null then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 select * into receipt from aamix_hw01.aamix_match_receipts where user_id=uid and request_id=p_request_id;
 if found then
  if not receipt.event_battle or receipt.deck_id is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023';end if;
  response:=aamix_hw01.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_deck',receipt.player_deck);
 else
  response:=aamix_hw01_private.begin_match(p_request_id,p_deck_id);
  update aamix_hw01.aamix_match_receipts set event_battle=true where match_id=(response->>'match_id')::uuid and user_id=uid;
 end if;
 return response||jsonb_build_object('event_battle',true,'event_opponent',aamix_hw01_private.halloween_deck());
end $$;
create function aamix_hw01.aamix_begin_event_match(p_request_id uuid,p_deck_id text) returns jsonb language sql security invoker set search_path='' as $$select aamix_hw01_private.begin_event_match(p_request_id,p_deck_id)$$;

-- Only this copied calendar is forced active. The response retains the planned dates.
update aamix_hw01_private.event_definitions set start_day='2026-01-01',end_day='2099-12-31' where id='halloween_2026';
update aamix_hw01_private.gift_code_rewards set cards='[{"codigo":"01b","cantidad":1}]',avatar_code='01b' where gift_code='GATONEGRO';

-- Fixed-schema, named-parameter RPC gateway. Authentication and RLS remain in force.
create function public.aamix_hw01_call(p_method text,p_args jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
#variable_conflict use_column
declare fn record;arg_name text;args text:='';i integer;value_type text;result jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 if p_method is null or p_method!~'^aamix_[a-z0-9_]+$' or p_args is null or jsonb_typeof(p_args)<>'object' or octet_length(p_args::text)>524288 then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 select p.* into fn from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='aamix_hw01' and p.proname=p_method and p.prorettype='jsonb'::regtype and has_function_privilege('authenticated',p.oid,'EXECUTE');
 if not found then raise exception 'AAMIX_PREVIEW_METHOD_UNAVAILABLE' using errcode='22023';end if;
 for arg_name in select jsonb_object_keys(p_args) loop
  if not arg_name=any(coalesce(fn.proargnames,'{}')) then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 end loop;
 perform aamix_hw01_private.bootstrap();
 for i in 1..fn.pronargs loop
  arg_name:=fn.proargnames[i];
  if not p_args?arg_name then continue;end if;
  value_type:=format_type(fn.proargtypes[i-1],null);
  args:=args||case when args='' then '' else ',' end||format('%I => ($1 %s %L)::%s',arg_name,case when value_type='jsonb' then '->' else '->>' end,arg_name,value_type);
 end loop;
 execute format('select aamix_hw01.%I(%s)',p_method,args) into result using p_args;
 return result;
end $$;
revoke all on function public.aamix_hw01_call(text,jsonb) from public,anon,authenticated;
grant execute on function public.aamix_hw01_call(text,jsonb) to authenticated;
revoke all on all functions in schema aamix_hw01,aamix_hw01_private from public,anon;
grant execute on function aamix_hw01_private.bootstrap(),aamix_hw01_private.open_halloween_pack(uuid),aamix_hw01_private.begin_event_match(uuid,text) to authenticated;
grant execute on function aamix_hw01.aamix_open_halloween_pack(uuid),aamix_hw01.aamix_begin_event_match(uuid,text) to authenticated;
