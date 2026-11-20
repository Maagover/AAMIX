-- AAMIX 0.17: private two-player, trusted-host friend beta over existing HTTPS RPC.
-- No authoritative rule simulation in SQL: Godot host runs the unchanged engine.
-- No new hosting subscription. Private data is available only through guarded RPCs.
create table aamix_private.mp_rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check(code ~ '^[0-9A-F]{8}$'),
  host_id uuid not null references auth.users(id) on delete cascade,
  guest_id uuid references auth.users(id) on delete cascade,
  create_request uuid not null,
  join_request uuid,
  host_deck jsonb not null,
  guest_deck jsonb,
  host_name text not null,
  guest_name text,
  status text not null default 'waiting' check(status in('waiting','ready','playing','finished','cancelled')),
  revision integer not null default 0 check(revision>=0),
  actor_slot integer not null default 0 check(actor_slot in(0,1)),
  winner integer not null default -1 check(winner in(-1,0,1)),
  host_state jsonb,
  guest_view jsonb,
  initial_request uuid,
  initial_digest text,
  host_receipt_request uuid not null default gen_random_uuid(),
  guest_receipt_request uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default(now()+interval '2 hours'),
  started_at timestamptz,
  finished_at timestamptz,
  host_seen timestamptz not null default now(),
  guest_seen timestamptz,
  finish_reason text,
  last_error text not null default '',
  unique(host_id,create_request),
  check(guest_id is null or guest_id<>host_id),
  check(host_state is null or octet_length(host_state::text)<=131072),
  check(guest_view is null or octet_length(guest_view::text)<=65536)
);
create table aamix_private.mp_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  room_id uuid not null references aamix_private.mp_rooms(id) on delete cascade
);
create index mp_members_room_idx on aamix_private.mp_members(room_id);
create table aamix_private.mp_commands (
  room_id uuid not null references aamix_private.mp_rooms(id) on delete cascade,
  request_id uuid not null,
  sender_id uuid not null references auth.users(id) on delete cascade,
  slot smallint not null check(slot in(0,1)),
  revision integer not null,
  method text not null,
  args jsonb not null,
  status text not null default 'pending' check(status in('pending','committed','rejected')),
  commit_digest text,
  created_at timestamptz not null default now(),
  primary key(room_id,request_id)
);
create unique index mp_one_pending_revision on aamix_private.mp_commands(room_id,revision) where status='pending';
alter table aamix_private.mp_rooms enable row level security;
alter table aamix_private.mp_members enable row level security;
alter table aamix_private.mp_commands enable row level security;
revoke all on aamix_private.mp_rooms,aamix_private.mp_members,aamix_private.mp_commands from public,anon,authenticated;
-- Receipts remain readable only by their pre-existing owner policy. IDs survive room retention.
alter table public.aamix_match_receipts add column online_room_id uuid;
create unique index aamix_online_receipt_once on public.aamix_match_receipts(online_room_id,user_id) where online_room_id is not null;

create function aamix_private.mp_deck(p_uid uuid,p_deck_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d jsonb;
begin
  select jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards)
    into d from public.aamix_owned_decks where user_id=p_uid and deck_id=p_deck_id;
  if d is null or (select coalesce(sum((e->>'cantidad')::integer),0) from jsonb_array_elements(d->'cartas')e)<>40 then
    raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023';
  end if;
  return d;
end $$;

create function aamix_private.mp_finish(p_room_id uuid,p_winner integer,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare r aamix_private.mp_rooms%rowtype; u uuid; receipt uuid; s integer;
begin
  select * into strict r from aamix_private.mp_rooms where id=p_room_id for update;
  if r.status in('finished','cancelled') then return; end if;
  if r.started_at is null or p_winner not in(0,1) then
    update aamix_private.mp_rooms set status='cancelled',finished_at=now(),winner=-1,finish_reason=p_reason where id=r.id;
  else
    update aamix_private.mp_rooms set status='finished',finished_at=now(),winner=p_winner,finish_reason=p_reason where id=r.id;
    for s in 0..1 loop
      u:=case s when 0 then r.host_id else r.guest_id end;
      insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,online_room_id)
        values(u,case s when 0 then r.host_receipt_request else r.guest_receipt_request end,
          case s when 0 then r.host_deck->>'id' else r.guest_deck->>'id' end,r.started_at,now(),
          case when s=p_winner then 'victory' else 'defeat' end,r.id)
        on conflict(online_room_id,user_id) where online_room_id is not null do nothing returning match_id into receipt;
      if receipt is not null then
        insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id)
          values(u,(now() at time zone 'America/Santiago')::date,receipt) on conflict(user_id,mission_day) do nothing;
      end if;
    end loop;
  end if;
  delete from aamix_private.mp_members where room_id=r.id;
  update aamix_private.mp_commands set status='rejected' where room_id=r.id and status='pending';
end $$;

create function aamix_private.mp_cleanup() returns void
language plpgsql security definer set search_path='' as $$
declare r record;
begin
  for r in select id from aamix_private.mp_rooms where status in('waiting','ready','playing') and
    (expires_at<now() or (status in('waiting','ready') and greatest(host_seen,coalesce(guest_seen,host_seen))<now()-interval '30 minutes') or
    (status='playing' and host_seen<now()-interval '180 seconds' and guest_seen<now()-interval '180 seconds'))
    for update skip locked loop
    perform aamix_private.mp_finish(r.id,-1,'expired');
  end loop;
  -- A room is recoverable for 7 days after completion; mission receipts are retained.
  delete from aamix_private.mp_rooms where status in('finished','cancelled') and finished_at<now()-interval '7 days';
end $$;

create function aamix_private.mp_response(p_room_id uuid,p_uid uuid,p_since integer default -1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r aamix_private.mp_rooms%rowtype; s integer; data jsonb;
begin
  select * into strict r from aamix_private.mp_rooms where id=p_room_id;
  s:=case when p_uid=r.host_id then 0 when p_uid=r.guest_id then 1 else -1 end;
  if s=-1 then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  data:=jsonb_build_object('room_id',r.id,'code',r.code,'status',r.status,'slot',s,'revision',r.revision,
    'actor_slot',r.actor_slot,'winner',r.winner,'expires_at',r.expires_at,'last_error',r.last_error,
    'finish_reason',r.finish_reason,'opponent_online',case when s=0 then r.guest_seen>now()-interval '20 seconds' else r.host_seen>now()-interval '20 seconds' end,
    'players',jsonb_build_array(
      jsonb_build_object('slot',0,'name',r.host_name,'deck_id',r.host_deck->>'id','deck_name',r.host_deck->>'nombre','cover',r.host_deck->>'portada'),
      case when r.guest_id is null then null else jsonb_build_object('slot',1,'name',r.guest_name,'deck_id',r.guest_deck->>'id','deck_name',r.guest_deck->>'nombre','cover',r.guest_deck->>'portada') end));
  if s=0 then
    data:=data||jsonb_build_object('host_deck',r.host_deck,'guest_deck',r.guest_deck,'commands',coalesce((
      select jsonb_agg(jsonb_build_object('request_id',c.request_id,'slot',c.slot,'method',c.method,'args',c.args,'revision',c.revision) order by c.created_at)
      from aamix_private.mp_commands c where c.room_id=r.id and c.status='pending'),'[]'::jsonb));
    data:=jsonb_set(data,'{players,0,deck}',r.host_deck);
    if r.guest_id is not null then data:=jsonb_set(data,'{players,1,deck}',r.guest_deck); end if;
  end if;
  if p_since<>r.revision then data:=data||jsonb_build_object('state',case s when 0 then r.host_state else r.guest_view end); end if;
  return data;
end $$;

create function aamix_private.mp_create_room(p_request_id uuid,p_deck_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; c text; n text;
begin
  if p_request_id is null then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(170017,1);
  perform aamix_private.mp_cleanup();
  select * into r from aamix_private.mp_rooms where host_id=uid and create_request=p_request_id;
  if found then
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
  insert into aamix_private.mp_rooms(code,host_id,create_request,host_deck,host_name) values(c,uid,p_request_id,d,n) returning * into r;
  insert into aamix_private.mp_members(user_id,room_id) values(uid,r.id);
  return aamix_private.mp_response(r.id,uid);
end $$;

create function aamix_private.mp_join_room(p_code text,p_deck_id text,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; n text;
begin
  if p_request_id is null or p_code is null or upper(btrim(p_code))!~'^[0-9A-F]{8}$' then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(170017,1);
  perform aamix_private.mp_cleanup();
  select * into r from aamix_private.mp_rooms where code=upper(btrim(p_code)) for update;
  if not found then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
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
end $$;

create function aamix_private.mp_poll(p_room_id uuid,p_since_revision integer default -1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; s integer;
begin
  select * into r from aamix_private.mp_rooms where id=p_room_id for update;
  if not found or uid not in(r.host_id,coalesce(r.guest_id,r.host_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  s:=case when uid=r.host_id then 0 else 1 end;
  if r.status in('waiting','ready','playing') and r.expires_at<now() then
    perform aamix_private.mp_finish(r.id,-1,'expired');
    update aamix_private.mp_rooms set revision=revision+1 where id=r.id;
  elsif r.status='playing' and (case s when 0 then r.guest_seen else r.host_seen end)<now()-interval '180 seconds' then
    perform aamix_private.mp_finish(r.id,s,'disconnected');
    update aamix_private.mp_rooms set revision=revision+1 where id=r.id;
  end if;
  update aamix_private.mp_rooms set host_seen=case s when 0 then now() else host_seen end,guest_seen=case s when 1 then now() else guest_seen end where id=r.id;
  return aamix_private.mp_response(r.id,uid,p_since_revision);
end $$;

create function aamix_private.mp_active() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); rid uuid;
begin
  select room_id into rid from aamix_private.mp_members where user_id=uid;
  if rid is null then return jsonb_build_object('room_id',null); end if;
  return aamix_private.mp_poll(rid,-1);
end $$;

create function aamix_private.mp_submit(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_method text,p_args jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; c aamix_private.mp_commands%rowtype; s integer;
begin
  if p_request_id is null or p_expected_revision is null or p_method is null or p_args is null or jsonb_typeof(p_args)<>'array' or
    octet_length(p_args::text)>4096 or p_args::text!~'^[0-9eE+., \[\]truefalsn-]*$' or
    p_method not in('mulligan','keep_hand','skip_resource','request_play','reserve_resource','refund_resource','cancel_payment','activate','choose','skip_choice','discard_by_drag','declare_attack','assign_block','finish_blocks','pass_priority','finish_turn') then
    raise exception 'AAMIX_INVALID_ACTION' using errcode='22023';
  end if;
  select * into r from aamix_private.mp_rooms where id=p_room_id for update;
  if not found or uid not in(r.host_id,coalesce(r.guest_id,r.host_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  select * into c from aamix_private.mp_commands where room_id=r.id and request_id=p_request_id;
  if found then
    if c.sender_id<>uid or c.revision<>p_expected_revision or c.method<>p_method or c.args<>p_args then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid)||jsonb_build_object('command_id',c.request_id,'command_status',c.status);
  end if;
  s:=case when uid=r.host_id then 0 else 1 end;
  if r.status<>'playing' then raise exception 'AAMIX_ROOM_NOT_PLAYING' using errcode='22023'; end if;
  if r.expires_at<now() then raise exception 'AAMIX_ROOM_EXPIRED' using errcode='22023'; end if;
  if r.revision<>p_expected_revision then raise exception 'AAMIX_STALE_REVISION' using errcode='40001'; end if;
  if r.actor_slot<>s then raise exception 'AAMIX_NOT_YOUR_TURN' using errcode='42501'; end if;
  if exists(select 1 from aamix_private.mp_commands where room_id=r.id and revision=r.revision and status='pending') then raise exception 'AAMIX_ACTION_PENDING' using errcode='55000'; end if;
  insert into aamix_private.mp_commands(room_id,request_id,sender_id,slot,revision,method,args) values(r.id,p_request_id,uid,s,p_expected_revision,p_method,p_args);
  update aamix_private.mp_rooms set host_seen=case s when 0 then now() else host_seen end,guest_seen=case s when 1 then now() else guest_seen end where id=r.id;
  return aamix_private.mp_response(r.id,uid)||jsonb_build_object('command_id',p_request_id,'command_status','pending');
end $$;

create function aamix_private.mp_validate_views(p_host jsonb,p_guest jsonb,p_actor integer,p_winner integer) returns void
language plpgsql security definer set search_path='' as $$
declare hidden jsonb; options jsonb;
begin
  if p_actor is null or p_actor not in(0,1) or p_winner is null or p_winner not in(-1,0,1) or p_host is null or p_guest is null or
    jsonb_typeof(p_host)<>'object' or jsonb_typeof(p_guest)<>'object' or octet_length(p_host::text)>131072 or octet_length(p_guest::text)>65536 or
    jsonb_typeof(p_host->'players') is distinct from 'array' or jsonb_array_length(p_host->'players')<>2 or
    jsonb_typeof(p_guest->'players') is distinct from 'array' or jsonb_array_length(p_guest->'players')<>2 or
    jsonb_typeof(p_host->'instances') is distinct from 'object' or jsonb_typeof(p_guest->'instances') is distinct from 'object' or
    (p_host->>'actor')::integer is distinct from p_actor or (p_guest->>'actor')::integer is distinct from p_actor or
    (p_host->>'winner')::integer is distinct from p_winner or (p_guest->>'winner')::integer is distinct from p_winner or
    p_guest->'queue' is distinct from '[]'::jsonb or p_guest->'log_lines' is distinct from '[]'::jsonb or
    p_guest->>'rng_seed' is distinct from '0' or p_guest->>'rng_state' is distinct from '0' then
    raise exception 'AAMIX_INVALID_SNAPSHOT' using errcode='22023';
  end if;
  if exists(select 1 from jsonb_array_elements(p_guest->'players')p cross join lateral jsonb_array_elements(p->'deck')u where u::text!~'^-[0-9]+$') or
    exists(select 1 from jsonb_array_elements(p_guest->'players'->0->'hand')u where u::text!~'^-[0-9]+$') then
    raise exception 'AAMIX_PRIVATE_VIEW' using errcode='22023';
  end if;
  options:=case when p_guest->'pending'->>'player'='1' then coalesce(p_guest->'pending'->'options','[]'::jsonb) else '[]'::jsonb end;
  select coalesce(jsonb_agg(u),'[]'::jsonb) into hidden from (
    select jsonb_array_elements(p_host->'players'->0->'deck')u
    union select jsonb_array_elements(p_host->'players'->0->'hand')
    union select u from jsonb_array_elements(p_host->'players'->1->'deck')u where not options@>jsonb_build_array(u))t;
  if exists(select 1 from jsonb_object_keys(p_guest->'instances')k where hidden@>jsonb_build_array(k::integer)) then
    raise exception 'AAMIX_PRIVATE_VIEW' using errcode='22023';
  end if;
end $$;

create function aamix_private.mp_commit(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb
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

create function aamix_private.mp_leave(p_room_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; s integer;
begin
  select * into r from aamix_private.mp_rooms where id=p_room_id for update;
  if not found or uid not in(r.host_id,coalesce(r.guest_id,r.host_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  if r.status not in('finished','cancelled') then
    s:=case when uid=r.host_id then 0 else 1 end;
    perform aamix_private.mp_finish(r.id,1-s,'left');
    update aamix_private.mp_rooms set revision=revision+1 where id=r.id;
  end if;
  return aamix_private.mp_response(r.id,uid);
end $$;

-- Public functions are invokers. Only these explicit guarded operations are callable.
create function public.aamix_mp_create_room(p_request_id uuid,p_deck_id text) returns jsonb language sql security invoker set search_path='' as $$select aamix_private.mp_create_room(p_request_id,p_deck_id);$$;
create function public.aamix_mp_join_room(p_code text,p_deck_id text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select aamix_private.mp_join_room(p_code,p_deck_id,p_request_id);$$;
create function public.aamix_mp_poll(p_room_id uuid,p_since_revision integer default -1) returns jsonb language sql security invoker set search_path='' as $$select aamix_private.mp_poll(p_room_id,p_since_revision);$$;
create function public.aamix_mp_active() returns jsonb language sql security invoker set search_path='' as $$select aamix_private.mp_active();$$;
create function public.aamix_mp_submit(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_method text,p_args jsonb) returns jsonb language sql security invoker set search_path='' as $$select aamix_private.mp_submit(p_room_id,p_request_id,p_expected_revision,p_method,p_args);$$;
create function public.aamix_mp_commit(p_room_id uuid,p_request_id uuid,p_expected_revision integer,p_host_state jsonb,p_guest_view jsonb,p_actor_slot integer,p_winner integer default -1,p_error text default '') returns jsonb language sql security invoker set search_path='' as $$select aamix_private.mp_commit(p_room_id,p_request_id,p_expected_revision,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);$$;
create function public.aamix_mp_leave(p_room_id uuid) returns jsonb language sql security invoker set search_path='' as $$select aamix_private.mp_leave(p_room_id);$$;

revoke all on function aamix_private.mp_deck(uuid,text),aamix_private.mp_finish(uuid,integer,text),aamix_private.mp_cleanup(),aamix_private.mp_response(uuid,uuid,integer),aamix_private.mp_validate_views(jsonb,jsonb,integer,integer) from public,anon,authenticated;
revoke all on function aamix_private.mp_create_room(uuid,text),aamix_private.mp_join_room(text,text,uuid),aamix_private.mp_poll(uuid,integer),aamix_private.mp_active(),aamix_private.mp_submit(uuid,uuid,integer,text,jsonb),aamix_private.mp_commit(uuid,uuid,integer,jsonb,jsonb,integer,integer,text),aamix_private.mp_leave(uuid) from public,anon,authenticated;
grant execute on function aamix_private.mp_create_room(uuid,text),aamix_private.mp_join_room(text,text,uuid),aamix_private.mp_poll(uuid,integer),aamix_private.mp_active(),aamix_private.mp_submit(uuid,uuid,integer,text,jsonb),aamix_private.mp_commit(uuid,uuid,integer,jsonb,jsonb,integer,integer,text),aamix_private.mp_leave(uuid) to authenticated;
revoke all on function public.aamix_mp_create_room(uuid,text),public.aamix_mp_join_room(text,text,uuid),public.aamix_mp_poll(uuid,integer),public.aamix_mp_active(),public.aamix_mp_submit(uuid,uuid,integer,text,jsonb),public.aamix_mp_commit(uuid,uuid,integer,jsonb,jsonb,integer,integer,text),public.aamix_mp_leave(uuid) from public,anon,authenticated;
grant execute on function public.aamix_mp_create_room(uuid,text),public.aamix_mp_join_room(text,text,uuid),public.aamix_mp_poll(uuid,integer),public.aamix_mp_active(),public.aamix_mp_submit(uuid,uuid,integer,text,jsonb),public.aamix_mp_commit(uuid,uuid,integer,jsonb,jsonb,integer,integer,text),public.aamix_mp_leave(uuid) to authenticated;
notify pgrst,'reload schema';
