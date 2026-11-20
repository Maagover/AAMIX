CREATE OR REPLACE FUNCTION aamix_private.mp_create_room_ruleset(p_request_id uuid, p_deck_id text, p_ruleset_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; c text; n text;
begin
  if p_ruleset_version is null or p_ruleset_version not in('1.2','1.3','1.9') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
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
  if p_ruleset_version<>'1.9' and exists(select 1 from jsonb_array_elements(d->'cartas')card_entry where card_entry->>'codigo' like 'H%') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023';end if;
  select left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),'Jugador'),24) into n from auth.users where id=uid;
  loop
    c:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from aamix_private.mp_rooms where code=c);
  end loop;
  insert into aamix_private.mp_rooms(code,host_id,create_request,host_deck,host_name,ruleset_version) values(c,uid,p_request_id,d,n,p_ruleset_version) returning * into r;
  insert into aamix_private.mp_members(user_id,room_id) values(uid,r.id);
  return aamix_private.mp_response(r.id,uid);
end $function$;
CREATE OR REPLACE FUNCTION aamix_private.mp_join_room_ruleset(p_code text, p_deck_id text, p_request_id uuid, p_ruleset_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; n text;
begin
  if p_ruleset_version is null or p_ruleset_version not in('1.2','1.3','1.9') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if p_request_id is null or p_code is null or upper(btrim(p_code))!~'^[0-9A-F]{8}$' then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(170017,1);
  perform aamix_private.mp_cleanup();
  select * into r from aamix_private.mp_rooms where code=upper(btrim(p_code)) for update;
  if not found then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
  -- Validate compatibility before replay, deck resolution or any membership mutation.
  if r.invited_user is not null and r.invited_user<>uid then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  if r.ruleset_version<>p_ruleset_version then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if r.guest_id=uid and r.join_request=p_request_id then
    if r.guest_deck->>'id' is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid);
  end if;
  if r.status<>'waiting' or r.guest_id is not null or r.host_id=uid then raise exception 'AAMIX_ROOM_UNAVAILABLE' using errcode='22023'; end if;
  if exists(select 1 from aamix_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023'; end if;
  d:=aamix_private.mp_deck(uid,p_deck_id);
  if p_ruleset_version<>'1.9' and exists(select 1 from jsonb_array_elements(d->'cartas')card_entry where card_entry->>'codigo' like 'H%') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023';end if;
  select left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),'Jugador'),24) into n from auth.users where id=uid;
  update aamix_private.mp_rooms set guest_id=uid,guest_deck=d,guest_name=n,join_request=p_request_id,status='ready',guest_seen=now() where id=r.id;
  insert into aamix_private.mp_members(user_id,room_id) values(uid,r.id);
  return aamix_private.mp_response(r.id,uid);
end $function$;

