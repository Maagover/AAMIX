-- AAMIX 1.3: keep the old transport protocol while isolating different rule engines.
-- Existing rooms and legacy RPC callers use ruleset 1.2. New explicit v130 RPCs use 1.3.
-- No accounts, collections, wallet, rewards, commands, receipts or historical revisions are reset.
alter table aamix_private.mp_rooms add column ruleset_version text not null default '1.2'
  check(ruleset_version in('1.2','1.3'));

CREATE FUNCTION aamix_private.mp_create_room_ruleset(p_request_id uuid, p_deck_id text, p_ruleset_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; c text; n text;
begin
  if p_ruleset_version is null or p_ruleset_version not in('1.2','1.3') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if p_request_id is null then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(170017,1);
  perform aamix_private.mp_cleanup();
  select * into r from aamix_private.mp_rooms where host_id=uid and create_request=p_request_id;
  if found then
    if r.ruleset_version<>p_ruleset_version then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
    if r.host_deck->>'id' is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid);
  end if;
  if exists(select 1 from aamix_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023'; end if;
  if (select count(*) from aamix_private.mp_rooms where status in('waiting','ready','playing'))>=8 then raise exception 'AAMIX_ROOMS_FULL' using errcode='53300'; end if;
  d:=aamix_private.mp_deck(uid,p_deck_id);
  select left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),'Jugador'),24) into n from auth.users where id=uid;
  loop
    c:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from aamix_private.mp_rooms where code=c);
  end loop;
  insert into aamix_private.mp_rooms(code,host_id,create_request,host_deck,host_name,ruleset_version) values(c,uid,p_request_id,d,n,p_ruleset_version) returning * into r;
  insert into aamix_private.mp_members(user_id,room_id) values(uid,r.id);
  return aamix_private.mp_response(r.id,uid);
end $function$;

CREATE FUNCTION aamix_private.mp_join_room_ruleset(p_code text, p_deck_id text, p_request_id uuid, p_ruleset_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; n text;
begin
  if p_ruleset_version is null or p_ruleset_version not in('1.2','1.3') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if p_request_id is null or p_code is null or upper(btrim(p_code))!~'^[0-9A-F]{8}$' then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(170017,1);
  perform aamix_private.mp_cleanup();
  select * into r from aamix_private.mp_rooms where code=upper(btrim(p_code)) for update;
  if not found then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
  -- Validate compatibility before replay, deck resolution or any membership mutation.
  if r.ruleset_version<>p_ruleset_version then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if r.guest_id=uid and r.join_request=p_request_id then
    if r.guest_deck->>'id' is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid);
  end if;
  if r.status<>'waiting' or r.guest_id is not null or r.host_id=uid then raise exception 'AAMIX_ROOM_UNAVAILABLE' using errcode='22023'; end if;
  if exists(select 1 from aamix_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023'; end if;
  d:=aamix_private.mp_deck(uid,p_deck_id);
  select left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),'Jugador'),24) into n from auth.users where id=uid;
  update aamix_private.mp_rooms set guest_id=uid,guest_deck=d,guest_name=n,join_request=p_request_id,status='ready',guest_seen=now() where id=r.id;
  insert into aamix_private.mp_members(user_id,room_id) values(uid,r.id);
  return aamix_private.mp_response(r.id,uid);
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.mp_response(p_room_id uuid, p_uid uuid, p_since integer DEFAULT '-1'::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r aamix_private.mp_rooms%rowtype; s integer; data jsonb;
begin
  select * into strict r from aamix_private.mp_rooms where id=p_room_id;
  s:=case when p_uid=r.host_id then 0 when p_uid=r.guest_id then 1 else -1 end;
  if s=-1 then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  data:=jsonb_build_object('protocol',3,'ruleset_version',r.ruleset_version,'room_version',r.room_version,'confirmed',jsonb_build_array(r.host_confirmed,r.guest_confirmed),'room_id',r.id,'code',r.code,'status',r.status,'slot',s,'revision',r.revision,
    'actor_slot',r.actor_slot,'winner',r.winner,'expires_at',r.expires_at,'last_error',r.last_error,
    'finish_reason',r.finish_reason,'opponent_online',case when s=0 then r.guest_seen>now()-interval '20 seconds' else r.host_seen>now()-interval '20 seconds' end,
    'players',jsonb_build_array(
      jsonb_build_object('slot',0,'avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=r.host_id),'name',r.host_name,'deck_id',r.host_deck->>'id','deck_name',r.host_deck->>'nombre','cover',r.host_deck->>'portada'),
      case when r.guest_id is null then null else jsonb_build_object('slot',1,'avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=r.guest_id),'name',r.guest_name,'deck_id',r.guest_deck->>'id','deck_name',r.guest_deck->>'nombre','cover',r.guest_deck->>'portada') end));
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
end $function$;


-- Internal generic helpers cannot be called by clients to select arbitrary room metadata.
revoke all on function aamix_private.mp_create_room_ruleset(uuid,text,text),aamix_private.mp_join_room_ruleset(text,text,uuid,text) from public,anon,authenticated;

-- Keep the existing private/public signatures for old 1.0/1.1/1.2 clients.
create or replace function aamix_private.mp_create_room(p_request_id uuid,p_deck_id text) returns jsonb
language sql security definer set search_path='' as $$
select aamix_private.mp_create_room_ruleset(p_request_id,p_deck_id,'1.2');
$$;
create or replace function aamix_private.mp_join_room(p_code text,p_deck_id text,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$
select aamix_private.mp_join_room_ruleset(p_code,p_deck_id,p_request_id,'1.2');
$$;

-- New entry points encode the supported ruleset in their endpoint, not in a client-supplied owner UUID.
create function aamix_private.mp_create_room_v130(p_request_id uuid,p_deck_id text) returns jsonb
language sql security definer set search_path='' as $$
select aamix_private.mp_create_room_ruleset(p_request_id,p_deck_id,'1.3');
$$;
create function aamix_private.mp_join_room_v130(p_code text,p_deck_id text,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$
select aamix_private.mp_join_room_ruleset(p_code,p_deck_id,p_request_id,'1.3');
$$;
revoke all on function aamix_private.mp_create_room(uuid,text),aamix_private.mp_join_room(text,text,uuid),
 aamix_private.mp_create_room_v130(uuid,text),aamix_private.mp_join_room_v130(text,text,uuid) from public,anon,authenticated;
grant execute on function aamix_private.mp_create_room(uuid,text),aamix_private.mp_join_room(text,text,uuid),
 aamix_private.mp_create_room_v130(uuid,text),aamix_private.mp_join_room_v130(text,text,uuid) to authenticated;

create function public.aamix_mp_create_room_v130(p_request_id uuid,p_deck_id text) returns jsonb
language sql security invoker set search_path='' as $$
select aamix_private.mp_create_room_v130(p_request_id,p_deck_id);
$$;
create function public.aamix_mp_join_room_v130(p_code text,p_deck_id text,p_request_id uuid) returns jsonb
language sql security invoker set search_path='' as $$
select aamix_private.mp_join_room_v130(p_code,p_deck_id,p_request_id);
$$;
revoke all on function public.aamix_mp_create_room_v130(uuid,text),public.aamix_mp_join_room_v130(text,text,uuid) from public,anon,authenticated;
grant execute on function public.aamix_mp_create_room_v130(uuid,text),public.aamix_mp_join_room_v130(text,text,uuid) to authenticated;


-- Shared transport operations also require the room's rule engine.
-- Clients never supply a user UUID. Membership is checked before disclosing compatibility.
create function aamix_private.mp_require_ruleset(p_room_id uuid,p_ruleset_version text) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype;
begin
  select * into r from aamix_private.mp_rooms where id=p_room_id;
  if not found or (uid<>r.host_id and (r.guest_id is null or uid<>r.guest_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  if p_ruleset_version is null or r.ruleset_version is distinct from p_ruleset_version then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
end $$;
revoke all on function aamix_private.mp_require_ruleset(uuid,text) from public,anon,authenticated;
grant execute on function aamix_private.mp_require_ruleset(uuid,text) to authenticated;

create function aamix_private.mp_require_snapshot_ruleset(p_host jsonb,p_guest jsonb,p_ruleset_version text) returns void
language plpgsql immutable security invoker set search_path='' as $$
begin
  -- Old snapshots omit the ruleset field. Explicit new snapshots are mandatory for 1.3.
  if coalesce(p_host->>'ruleset_version','1.2') is distinct from p_ruleset_version
    or coalesce(p_guest->>'ruleset_version','1.2') is distinct from p_ruleset_version then
    raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023';
  end if;
end $$;
revoke all on function aamix_private.mp_require_snapshot_ruleset(jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function aamix_private.mp_require_snapshot_ruleset(jsonb,jsonb,text) to authenticated;

create function aamix_private.mp_active_ruleset(p_ruleset_version text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype;
begin
  select room.* into r from aamix_private.mp_rooms room join aamix_private.mp_members member on member.room_id=room.id where member.user_id=uid;
  if not found then return jsonb_build_object('room_id',null); end if;
  if r.ruleset_version is distinct from p_ruleset_version then
    if p_ruleset_version<>'1.3' then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
    -- A newer client may offer closing an old room without restoring its rules engine.
    return jsonb_build_object('protocol',3,'room_id',r.id,'code',r.code,'status',r.status,'ruleset_version',r.ruleset_version,
      'incompatible',true,'revision',r.revision,'room_version',r.room_version,'slot',case when uid=r.host_id then 0 else 1 end);
  end if;
  return aamix_private.mp_poll(r.id,-1);
end $$;
revoke all on function aamix_private.mp_active_ruleset(text) from public,anon,authenticated;
grant execute on function aamix_private.mp_active_ruleset(text) to authenticated;

create or replace function public.aamix_mp_poll(p_room_id uuid,p_since_revision integer default -1) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.2');
  return aamix_private.mp_poll(p_room_id,p_since_revision);
end $$;
revoke all on function public.aamix_mp_poll(uuid,integer) from public,anon,authenticated;
grant execute on function public.aamix_mp_poll(uuid,integer) to authenticated;

create or replace function public.aamix_mp_active() returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  return aamix_private.mp_active_ruleset('1.2');
end $$;
revoke all on function public.aamix_mp_active() from public,anon,authenticated;
grant execute on function public.aamix_mp_active() to authenticated;

create or replace function public.aamix_mp_confirm(p_room_id uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.2');
  return aamix_private.mp_confirm(p_room_id);
end $$;
revoke all on function public.aamix_mp_confirm(uuid) from public,anon,authenticated;
grant execute on function public.aamix_mp_confirm(uuid) to authenticated;

create or replace function public.aamix_mp_submit(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_method text,p_args jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.2');
  return aamix_private.mp_submit(p_room_id,p_request_id,p_expected_revision,p_method,p_args);
end $$;
revoke all on function public.aamix_mp_submit(uuid,uuid,integer,text,jsonb) from public,anon,authenticated;
grant execute on function public.aamix_mp_submit(uuid,uuid,integer,text,jsonb) to authenticated;

create or replace function public.aamix_mp_commit(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.2');
  perform aamix_private.mp_require_snapshot_ruleset(p_host_state,p_guest_view,'1.2');
  return aamix_private.mp_commit(p_room_id,p_request_id,p_expected_revision,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);
end $$;
revoke all on function public.aamix_mp_commit(uuid,uuid,integer,jsonb,jsonb,integer,integer,text) from public,anon,authenticated;
grant execute on function public.aamix_mp_commit(uuid,uuid,integer,jsonb,jsonb,integer,integer,text) to authenticated;

create or replace function public.aamix_mp_host_action(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_method text,p_args jsonb,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.2');
  perform aamix_private.mp_require_snapshot_ruleset(p_host_state,p_guest_view,'1.2');
  return aamix_private.mp_host_action(p_room_id,p_request_id,p_expected_revision,p_method,p_args,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);
end $$;
revoke all on function public.aamix_mp_host_action(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text) from public,anon,authenticated;
grant execute on function public.aamix_mp_host_action(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text) to authenticated;

create function public.aamix_mp_poll_v130(p_room_id uuid,p_since_revision integer default -1) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.3');
  return aamix_private.mp_poll(p_room_id,p_since_revision);
end $$;
revoke all on function public.aamix_mp_poll_v130(uuid,integer) from public,anon,authenticated;
grant execute on function public.aamix_mp_poll_v130(uuid,integer) to authenticated;

create function public.aamix_mp_active_v130() returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  return aamix_private.mp_active_ruleset('1.3');
end $$;
revoke all on function public.aamix_mp_active_v130() from public,anon,authenticated;
grant execute on function public.aamix_mp_active_v130() to authenticated;

create function public.aamix_mp_confirm_v130(p_room_id uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.3');
  return aamix_private.mp_confirm(p_room_id);
end $$;
revoke all on function public.aamix_mp_confirm_v130(uuid) from public,anon,authenticated;
grant execute on function public.aamix_mp_confirm_v130(uuid) to authenticated;

create function public.aamix_mp_submit_v130(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_method text,p_args jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.3');
  return aamix_private.mp_submit(p_room_id,p_request_id,p_expected_revision,p_method,p_args);
end $$;
revoke all on function public.aamix_mp_submit_v130(uuid,uuid,integer,text,jsonb) from public,anon,authenticated;
grant execute on function public.aamix_mp_submit_v130(uuid,uuid,integer,text,jsonb) to authenticated;

create function public.aamix_mp_commit_v130(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.3');
  perform aamix_private.mp_require_snapshot_ruleset(p_host_state,p_guest_view,'1.3');
  return aamix_private.mp_commit(p_room_id,p_request_id,p_expected_revision,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);
end $$;
revoke all on function public.aamix_mp_commit_v130(uuid,uuid,integer,jsonb,jsonb,integer,integer,text) from public,anon,authenticated;
grant execute on function public.aamix_mp_commit_v130(uuid,uuid,integer,jsonb,jsonb,integer,integer,text) to authenticated;

create function public.aamix_mp_host_action_v130(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_method text,p_args jsonb,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.3');
  perform aamix_private.mp_require_snapshot_ruleset(p_host_state,p_guest_view,'1.3');
  return aamix_private.mp_host_action(p_room_id,p_request_id,p_expected_revision,p_method,p_args,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);
end $$;
revoke all on function public.aamix_mp_host_action_v130(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text) from public,anon,authenticated;
grant execute on function public.aamix_mp_host_action_v130(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text) to authenticated;

-- The existing leave endpoint intentionally permits both rulesets for safe cancellation/abandonment.
notify pgrst,'reload schema';

