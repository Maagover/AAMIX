-- Server snapshots are filtered separately for each seat. Auth identities unchanged.
create or replace function aamix_private.mp_response(p_room_id uuid,p_uid uuid,p_since integer default -1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r aamix_private.mp_rooms%rowtype; s integer; data jsonb;
begin
  select * into strict r from aamix_private.mp_rooms where id=p_room_id;
  s:=case when p_uid=r.host_id then 0 when p_uid=r.guest_id then 1 else -1 end;
  if s=-1 then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  data:=jsonb_build_object('protocol',3,'confirmed',jsonb_build_array(r.host_confirmed,r.guest_confirmed),'room_id',r.id,'code',r.code,'status',r.status,'slot',s,'revision',r.revision,
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
end $$;

-- AAMIX v1.0: authenticated per-user, receive-only Realtime inboxes.
-- No client broadcast INSERT policy: clients cannot forge a server confirmation.
create policy aamix_own_inbox on realtime.messages for select to authenticated using(
  extension='broadcast' and (select realtime.topic())='aamix:user:'||(select auth.uid())::text);
create function aamix_private.mp_notify_room() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' and new.revision=old.revision and new.status=old.status
    and new.guest_id is not distinct from old.guest_id
    and new.host_confirmed=old.host_confirmed and new.guest_confirmed=old.guest_confirmed then return null; end if;
  perform realtime.send(aamix_private.mp_response(new.id,new.host_id,-1),'room','aamix:user:'||new.host_id::text,true);
  if new.guest_id is not null then
    perform realtime.send(aamix_private.mp_response(new.id,new.guest_id,-1),'room','aamix:user:'||new.guest_id::text,true);
  end if;
  return null;
end $$;
create function aamix_private.mp_notify_command() returns trigger
language plpgsql security definer set search_path='' as $$
declare host_uid uuid;
begin
  if new.slot<>1 or new.status<>'pending' then return null; end if;
  select host_id into strict host_uid from aamix_private.mp_rooms where id=new.room_id;
  perform realtime.send(aamix_private.mp_response(new.room_id,host_uid,-1),'room','aamix:user:'||host_uid::text,true);
  return null;
end $$;
revoke all on function aamix_private.mp_notify_room(),aamix_private.mp_notify_command() from public,anon,authenticated;
create trigger aamix_room_notify after insert or update on aamix_private.mp_rooms for each row execute function aamix_private.mp_notify_room();
create trigger aamix_command_notify after insert on aamix_private.mp_commands for each row execute function aamix_private.mp_notify_command();
