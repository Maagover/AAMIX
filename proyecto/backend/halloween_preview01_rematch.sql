-- Finished games negotiate a new, independent room. No receipt or revision is reused.
create function aamix_hw01_private.rematch_deck_current(p_uid uuid,p_deck jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare cards jsonb;is_draft boolean;
begin
 select d.cards,d.draft into cards,is_draft from aamix_hw01.aamix_owned_decks d where user_id=p_uid and deck_id=p_deck->>'id' for share;
 if not found then select d.cards,d.draft into cards,is_draft from aamix_hw01.aamix_custom_decks d where user_id=p_uid and deck_id=p_deck->>'id' for share;end if;
 if cards is null or is_draft or cards is distinct from p_deck->'cartas' then return false;end if;
 perform 1 from aamix_hw01.aamix_collection where user_id=p_uid for share;
 return not exists(select 1 from jsonb_array_elements(cards)e where coalesce((select quantity from aamix_hw01.aamix_collection where user_id=p_uid and code=e->>'codigo'),0)<(e->>'cantidad')::integer);
end$$;
revoke all on function aamix_hw01_private.rematch_deck_current(uuid,jsonb) from public,anon,authenticated;
create function aamix_hw01_private.rematch_action(p_room_id uuid,p_request_id uuid,p_action text,p_deck_id text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();r aamix_hw01_private.mp_rooms%rowtype;
 next_room aamix_hw01_private.mp_rooms%rowtype;payload jsonb;previous jsonb;d jsonb;c text;s integer;
begin
 if p_request_id is null or p_action is null or p_action not in('request','choose','ready','cancel') then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 -- Same lock ordering as room creation. This lock is exclusive to the preview.
 perform pg_advisory_xact_lock(190001,1);
 select * into r from aamix_hw01_private.mp_rooms where id=p_room_id for update;
 if not found or uid not in(r.host_id,coalesce(r.guest_id,r.host_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501';end if;
 s:=case when uid=r.host_id then 0 else 1 end;
 payload:=jsonb_build_object('room',p_room_id,'action',p_action,'deck',p_deck_id);
 select q.payload into previous from aamix_hw01_private.mp_rematch_requests q where q.user_id=uid and q.request_id=p_request_id;
 if found then
  if previous<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023';end if;
  return aamix_hw01_private.mp_response(r.id,uid);
 end if;
 if r.status<>'finished' or r.guest_id is null then raise exception 'AAMIX_ROOM_NOT_FINISHED' using errcode='22023';end if;
 if p_action='cancel' then
  if r.rematch_room is not null then
   select * into next_room from aamix_hw01_private.mp_rooms where id=r.rematch_room for update;
   if next_room.status in('waiting','ready','playing') then perform aamix_hw01_private.mp_leave(next_room.id);end if;
  end if;
  update aamix_hw01_private.mp_rooms set rematch_cancelled=true,host_rematch_ready=false,guest_rematch_ready=false,room_version=room_version+1 where id=r.id;
 else
  if r.rematch_cancelled then raise exception 'AAMIX_REMATCH_CANCELLED' using errcode='22023';end if;
  if r.rematch_room is not null then raise exception 'AAMIX_REMATCH_STARTED' using errcode='22023';end if;
  if exists(select 1 from aamix_hw01_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023';end if;
  if p_action in('request','choose') then
   d:=aamix_hw01_private.mp_deck(uid,p_deck_id);
   if s=0 then
    update aamix_hw01_private.mp_rooms set host_rematch=true,host_next_deck=d,host_rematch_ready=false,room_version=room_version+1 where id=r.id;
   else
    update aamix_hw01_private.mp_rooms set guest_rematch=true,guest_next_deck=d,guest_rematch_ready=false,room_version=room_version+1 where id=r.id;
   end if;
  else
   if not(r.host_rematch and r.guest_rematch) then raise exception 'AAMIX_REMATCH_WAITING' using errcode='22023';end if;
   -- Validate ownership and playability again when confirming.
   d:=aamix_hw01_private.mp_deck(uid,case s when 0 then r.host_next_deck->>'id' else r.guest_next_deck->>'id' end);
   if s=0 then update aamix_hw01_private.mp_rooms set host_next_deck=d,host_rematch_ready=true,room_version=room_version+1 where id=r.id;
   else update aamix_hw01_private.mp_rooms set guest_next_deck=d,guest_rematch_ready=true,room_version=room_version+1 where id=r.id;end if;
  end if;
  select * into r from aamix_hw01_private.mp_rooms where id=p_room_id;
  if r.host_rematch and r.guest_rematch and r.host_rematch_ready and r.guest_rematch_ready then
   if (select count(*) from aamix_hw01_private.mp_rooms where status in('waiting','ready','playing'))>=8 then raise exception 'AAMIX_ROOMS_FULL' using errcode='53300';end if;
   if exists(select 1 from aamix_hw01_private.mp_members where user_id in(r.host_id,r.guest_id)) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023';end if;
   if not aamix_hw01_private.rematch_deck_current(r.host_id,r.host_next_deck) or not aamix_hw01_private.rematch_deck_current(r.guest_id,r.guest_next_deck) then raise exception 'AAMIX_DECK_CHANGED' using errcode='22023';end if;
   loop
    c:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from aamix_hw01_private.mp_rooms where code=c);
   end loop;
   insert into aamix_hw01_private.mp_rooms(code,host_id,guest_id,create_request,join_request,host_deck,guest_deck,host_name,guest_name,status,host_confirmed,guest_confirmed,guest_seen,ruleset_version)
    values(c,r.host_id,r.guest_id,gen_random_uuid(),gen_random_uuid(),r.host_next_deck,r.guest_next_deck,r.host_name,r.guest_name,'ready',true,true,now(),r.ruleset_version) returning * into next_room;
   insert into aamix_hw01_private.mp_members(user_id,room_id) values(r.host_id,next_room.id),(r.guest_id,next_room.id);
   update aamix_hw01_private.mp_rooms set rematch_room=next_room.id,room_version=room_version+1 where id=r.id;
  end if;
 end if;
 insert into aamix_hw01_private.mp_rematch_requests(user_id,request_id,payload) values(uid,p_request_id,payload);
 return aamix_hw01_private.mp_response(r.id,uid);
end $$;
create function aamix_hw01.aamix_mp_rematch(p_room_id uuid,p_request_id uuid,p_action text,p_deck_id text default null)
returns jsonb language sql security invoker set search_path='' as $$select aamix_hw01_private.rematch_action(p_room_id,p_request_id,p_action,p_deck_id)$$;
revoke all on function aamix_hw01_private.rematch_action(uuid,uuid,text,text),aamix_hw01.aamix_mp_rematch(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function aamix_hw01_private.rematch_action(uuid,uuid,text,text),aamix_hw01.aamix_mp_rematch(uuid,uuid,text,text) to authenticated;

-- Reuse of an event receipt through the ordinary start endpoint is rejected too.
do $$declare definition text;begin
 select pg_get_functiondef('aamix_hw01_private.begin_match(uuid,text)'::regprocedure) into definition;
 definition:=replace(definition,'or receipt.online_room_id is not null then','or receipt.online_room_id is not null or receipt.event_battle then');
 execute definition;
end$$;
