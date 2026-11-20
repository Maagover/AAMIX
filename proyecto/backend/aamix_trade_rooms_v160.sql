-- AAMIX1.6: one live trade room per player; invitation then ordered choices.
-- Existing accounts, ownership, completed exchanges and reward ledgers are preserved.
create table aamix_private.trade_rooms_v160(
 id uuid primary key default gen_random_uuid(),
 a_id uuid not null references auth.users(id) on delete cascade,
 b_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'invited' check(status in('invited','host_offer','guest_offer','confirming','completed','cancelled','expired')),
 revision integer not null default 1 check(revision>0),
 a_code text references aamix_private.catalog_codes(code),b_code text references aamix_private.catalog_codes(code),
 a_confirmed boolean not null default false,b_confirmed boolean not null default false,
 a_seen timestamptz,b_seen timestamptz,
 created_at timestamptz not null default clock_timestamp(),expires_at timestamptz not null default clock_timestamp()+interval '15 minutes',
 closed_at timestamptz,close_reason text not null default '',
 a_drafts jsonb not null default '[]',b_drafts jsonb not null default '[]',check(a_id<>b_id)
);
create index trade_rooms_a_v160 on aamix_private.trade_rooms_v160(a_id,created_at desc);
create index trade_rooms_b_v160 on aamix_private.trade_rooms_v160(b_id,created_at desc);
create table aamix_private.trade_members_v160(
 user_id uuid primary key references auth.users(id) on delete cascade,
 room_id uuid not null references aamix_private.trade_rooms_v160(id) on delete cascade
);
create index trade_members_room_v160 on aamix_private.trade_members_v160(room_id);
alter table aamix_private.trade_rooms_v160 enable row level security;
alter table aamix_private.trade_members_v160 enable row level security;
create policy trade_rooms_server_v160 on aamix_private.trade_rooms_v160 for all to anon,authenticated using(false) with check(false);
create policy trade_members_server_v160 on aamix_private.trade_members_v160 for all to anon,authenticated using(false) with check(false);
revoke all on aamix_private.trade_rooms_v160,aamix_private.trade_members_v160 from public,anon,authenticated;

-- Old outstanding offers have never transferred their cards. Release only their reservations.
update aamix_private.card_trades set status='cancelled',a_confirmed=false,b_confirmed=false,revision=revision+1 where status='open';

create function aamix_private.trade_room_view_v160(p_room uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user();r aamix_private.trade_rooms_v160%rowtype;is_host boolean;
begin
 select * into r from aamix_private.trade_rooms_v160 where uid in(a_id,b_id) and (p_room is null or id=p_room) order by created_at desc,id desc limit 1;
 if not found then return '{}'::jsonb;end if;
 is_host:=uid=r.a_id;
 return jsonb_build_object('id',r.id,'role',case when is_host then 'host' else 'guest' end,'peer',aamix_private.social_peer(case when is_host then r.b_id else r.a_id end),
 'status',r.status,'revision',r.revision,'active',r.status in('invited','host_offer','guest_offer','confirming'),
 'own_code',coalesce(case when is_host then r.a_code else r.b_code end,''),'peer_code',coalesce(case when is_host then r.b_code else r.a_code end,''),
 'own_confirmed',case when is_host then r.a_confirmed else r.b_confirmed end,'peer_confirmed',case when is_host then r.b_confirmed else r.a_confirmed end,
 'host_connected',coalesce(r.a_seen>clock_timestamp()-interval '20 seconds',false),
 'guest_connected',coalesce(r.b_seen>clock_timestamp()-interval '20 seconds',false),
 'drafts',case when is_host then r.a_drafts else r.b_drafts end,'expires_at',r.expires_at,'close_reason',r.close_reason);
end $$;

-- Caller holds the room-state advisory lock. This lock is always taken BEFORE the ordered wallets.
create function aamix_private.trade_room_cleanup_v160(p_uid uuid) returns void language plpgsql set search_path='' as $$
declare r record;
begin
 for r in select id,expires_at from aamix_private.trade_rooms_v160 where p_uid in(a_id,b_id)
 and status in('invited','host_offer','guest_offer','confirming')
 and (expires_at<=clock_timestamp() or not aamix_private.social_is_friend(a_id,b_id)) order by id for update loop
  update aamix_private.trade_rooms_v160 set status=case when r.expires_at<=clock_timestamp() then 'expired' else 'cancelled' end,
   close_reason=case when r.expires_at<=clock_timestamp() then 'expired' else 'friend_removed' end,
   a_confirmed=false,b_confirmed=false,revision=revision+1,closed_at=clock_timestamp() where id=r.id;
  delete from aamix_private.trade_members_v160 where room_id=r.id;
 end loop;
end $$;

create function aamix_private.trade_room_reply_v160(p_room uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare view jsonb:=aamix_private.trade_room_view_v160(p_room);reply jsonb;
begin
 reply:=aamix_private.social_inventory()||jsonb_build_object('trade_room',view);
 if view->>'status'='completed' then reply:=reply||jsonb_build_object('inventory',public.aamix_inventory());end if;
 return reply;
end $$;

create function aamix_private.trade_room_create_v160(p_peer uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid;payload jsonb:=jsonb_build_object('peer',p_peer);replay jsonb;room_id uuid;
begin
 perform pg_advisory_xact_lock(170016,1);
 uid:=aamix_private.social_lock_pair(p_peer);
 replay:=aamix_private.social_replay(p_request_id,'trade_room_create_v160',payload);
 if replay is not null then return aamix_private.trade_room_reply_v160((replay->>'room_id')::uuid);end if;
 if not aamix_private.social_is_friend(uid,p_peer) then raise exception 'AAMIX_NOT_FRIENDS' using errcode='42501';end if;
 perform aamix_private.trade_room_cleanup_v160(uid);perform aamix_private.trade_room_cleanup_v160(p_peer);
 if exists(select 1 from aamix_private.trade_members_v160 where user_id in(uid,p_peer)) then raise exception 'AAMIX_ALREADY_TRADING' using errcode='22023';end if;
 insert into aamix_private.trade_rooms_v160(a_id,b_id,a_seen) values(uid,p_peer,clock_timestamp()) returning id into room_id;
 insert into aamix_private.trade_members_v160(user_id,room_id) select x,room_id from unnest(array[uid,p_peer]) x order by x;
 insert into aamix_private.social_requests values(uid,p_request_id,'trade_room_create_v160',payload,jsonb_build_object('room_id',room_id),now());
 return aamix_private.trade_room_reply_v160(room_id);
end $$;

create function aamix_private.trade_room_poll_v160(p_room uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user();r aamix_private.trade_rooms_v160%rowtype;peer uuid;
begin
 select * into r from aamix_private.trade_rooms_v160 where id=p_room and uid in(a_id,b_id);
 if not found then raise exception 'AAMIX_TRADE_UNAVAILABLE' using errcode='42501';end if;
 perform pg_advisory_xact_lock(170016,1);
 peer:=case when uid=r.a_id then r.b_id else r.a_id end;perform aamix_private.social_lock_pair(peer);
 perform aamix_private.trade_room_cleanup_v160(uid);
 select * into strict r from aamix_private.trade_rooms_v160 where id=p_room for update;
 if r.status in('invited','host_offer','guest_offer','confirming') then
  if r.a_confirmed or r.b_confirmed then
   if r.a_seen is null or r.b_seen is null or r.a_seen<=clock_timestamp()-interval '20 seconds' or r.b_seen<=clock_timestamp()-interval '20 seconds' then
    update aamix_private.trade_rooms_v160 set a_confirmed=false,b_confirmed=false,revision=revision+1 where id=r.id;
   end if;
  end if;
  update aamix_private.trade_rooms_v160 set
   a_seen=case when uid=a_id then clock_timestamp() else a_seen end,
   b_seen=case when uid=b_id and status<>'invited' then clock_timestamp() else b_seen end where id=r.id;
 end if;
 return aamix_private.trade_room_reply_v160(r.id);
end $$;

create function aamix_private.trade_room_action_v160(p_room uuid,p_action text,p_code text,p_revision integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user();r aamix_private.trade_rooms_v160%rowtype;peer uuid;payload jsonb;replay jsonb;drafts_a jsonb;drafts_b jsonb;
begin
 select * into r from aamix_private.trade_rooms_v160 where id=p_room and uid in(a_id,b_id);
 if not found then raise exception 'AAMIX_TRADE_UNAVAILABLE' using errcode='42501';end if;
 perform pg_advisory_xact_lock(170016,1);
 peer:=case when uid=r.a_id then r.b_id else r.a_id end;perform aamix_private.social_lock_pair(peer);
 payload:=jsonb_build_object('room',p_room,'action',p_action,'code',p_code,'revision',p_revision);
 replay:=aamix_private.social_replay(p_request_id,'trade_room_action_v160',payload);
 if replay is not null then return aamix_private.trade_room_reply_v160(p_room);end if;
 perform aamix_private.trade_room_cleanup_v160(uid);
 select * into strict r from aamix_private.trade_rooms_v160 where id=p_room for update;
 if r.status not in('invited','host_offer','guest_offer','confirming') then
  if p_action<>'cancel' then raise exception 'AAMIX_TRADE_CLOSED' using errcode='22023';end if;
 elsif p_action='cancel' then
  update aamix_private.trade_rooms_v160 set status='cancelled',close_reason='cancelled',closed_at=clock_timestamp(),a_confirmed=false,b_confirmed=false,revision=revision+1 where id=r.id;
  delete from aamix_private.trade_members_v160 where room_id=r.id;
 else
  if p_revision is null or p_revision<>r.revision then raise exception 'AAMIX_TRADE_CHANGED' using errcode='40001';end if;
  if p_action='accept' then
   if uid<>r.b_id or r.status<>'invited' then raise exception 'AAMIX_TRADE_TURN' using errcode='22023';end if;
   update aamix_private.trade_rooms_v160 set status='host_offer',b_seen=clock_timestamp(),revision=revision+1 where id=r.id;
  else
   if r.a_seen is null or r.b_seen is null or r.a_seen<=clock_timestamp()-interval '20 seconds' or r.b_seen<=clock_timestamp()-interval '20 seconds' then raise exception 'AAMIX_TRADE_NOT_CONNECTED' using errcode='22023';end if;
   if p_action='offer' then
    if not ((uid=r.a_id and r.status='host_offer') or (uid=r.b_id and r.status='guest_offer')) then raise exception 'AAMIX_TRADE_TURN' using errcode='22023';end if;
    if aamix_private.trade_family(p_code) is null then raise exception 'AAMIX_CARD_NOT_TRADABLE' using errcode='22023';end if;
    if r.a_code is not null and aamix_private.trade_family(r.a_code)<>aamix_private.trade_family(p_code) then raise exception 'AAMIX_TRADE_CATEGORY' using errcode='22023';end if;
    if not exists(select 1 from public.aamix_collection where user_id=uid and code=p_code and quantity>=1) then raise exception 'AAMIX_TRADE_NO_COPY' using errcode='22023';end if;
    update aamix_private.trade_rooms_v160 set a_code=case when uid=a_id then p_code else a_code end,
     b_code=case when uid=b_id then p_code else b_code end,status=case when uid=a_id then 'guest_offer' else 'confirming' end,
     a_confirmed=false,b_confirmed=false,revision=revision+1 where id=r.id;
   elsif p_action='confirm' then
    if r.status<>'confirming' or r.a_code is null or r.b_code is null then raise exception 'AAMIX_TRADE_INCOMPLETE' using errcode='22023';end if;
    if aamix_private.trade_family(r.a_code) is null or aamix_private.trade_family(r.a_code) is distinct from aamix_private.trade_family(r.b_code) then raise exception 'AAMIX_TRADE_CATEGORY' using errcode='22023';end if;
    if not exists(select 1 from public.aamix_collection where user_id=r.a_id and code=r.a_code and quantity>=1)
     or not exists(select 1 from public.aamix_collection where user_id=r.b_id and code=r.b_code and quantity>=1) then raise exception 'AAMIX_TRADE_NO_COPY' using errcode='22023';end if;
    update aamix_private.trade_rooms_v160 set a_confirmed=a_confirmed or uid=a_id,b_confirmed=b_confirmed or uid=b_id where id=r.id returning * into r;
    if r.a_confirmed and r.b_confirmed then
     if r.a_code<>r.b_code then
      delete from public.aamix_collection where ((user_id=r.a_id and code=r.a_code) or (user_id=r.b_id and code=r.b_code)) and quantity=1;
      update public.aamix_collection set quantity=quantity-1 where ((user_id=r.a_id and code=r.a_code) or (user_id=r.b_id and code=r.b_code));
      insert into public.aamix_collection(user_id,code,quantity) select r.a_id,r.b_code,1 union all select r.b_id,r.a_code,1 on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+1;
     end if;
     drafts_a:=aamix_private.trade_trim_decks(r.a_id);drafts_b:=aamix_private.trade_trim_decks(r.b_id);
     update aamix_private.trade_rooms_v160 set status='completed',closed_at=clock_timestamp(),revision=revision+1,a_drafts=drafts_a,b_drafts=drafts_b where id=r.id;
     delete from aamix_private.trade_members_v160 where room_id=r.id;
    end if;
   else raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
  end if;
 end if;
 insert into aamix_private.social_requests values(uid,p_request_id,'trade_room_action_v160',payload,jsonb_build_object('room_id',r.id),now());
 return aamix_private.trade_room_reply_v160(r.id);
end $$;

-- GENERATED EXTENSIONS
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
 return jsonb_build_object('user_id',uid,'friend_code',code,'friends',friends,'incoming',incoming,'outgoing',outgoing,'trades',trades,'duels',duels,'tradable_cards',cards,'trade_room',aamix_private.trade_room_view_v160());
end $function$
;
create or replace function aamix_private.trade_create(p_peer uuid,p_code text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$ begin perform aamix_private.reward_user(); raise exception 'AAMIX_TRADE_UPDATE_REQUIRED' using errcode='22023'; end $$;
create or replace function aamix_private.trade_action(p_trade uuid,p_action text,p_code text,p_revision integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$ begin perform aamix_private.reward_user(); raise exception 'AAMIX_TRADE_UPDATE_REQUIRED' using errcode='22023'; end $$;
create or replace function aamix_private.trade_available(p_uid uuid,p_code text,p_except uuid default null) returns integer language sql stable set search_path='' as $$
select greatest(0,coalesce((select quantity from public.aamix_collection where user_id=p_uid and code=p_code),0)
 -(select count(*)::integer from aamix_private.trade_rooms_v160 r where status in('host_offer','guest_offer','confirming') and expires_at>now()
 and ((a_id=p_uid and a_code=p_code) or (b_id=p_uid and b_code=p_code)))) $$;
revoke all on function aamix_private.trade_room_view_v160(uuid) from public,anon,authenticated;
revoke all on function aamix_private.trade_room_cleanup_v160(uuid) from public,anon,authenticated;
revoke all on function aamix_private.trade_room_reply_v160(uuid) from public,anon,authenticated;
revoke all on function aamix_private.trade_room_create_v160(uuid,uuid) from public,anon,authenticated;
grant execute on function aamix_private.trade_room_create_v160(uuid,uuid) to authenticated;
create function public.aamix_trade_room_create(p_peer uuid,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.trade_room_create_v160(p_peer,p_request_id) $$;
revoke all on function public.aamix_trade_room_create(uuid,uuid) from public,anon,authenticated;
grant execute on function public.aamix_trade_room_create(uuid,uuid) to authenticated;
revoke all on function aamix_private.trade_room_poll_v160(uuid) from public,anon,authenticated;
grant execute on function aamix_private.trade_room_poll_v160(uuid) to authenticated;
create function public.aamix_trade_room_poll(p_room uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.trade_room_poll_v160(p_room) $$;
revoke all on function public.aamix_trade_room_poll(uuid) from public,anon,authenticated;
grant execute on function public.aamix_trade_room_poll(uuid) to authenticated;
revoke all on function aamix_private.trade_room_action_v160(uuid,text,text,integer,uuid) from public,anon,authenticated;
grant execute on function aamix_private.trade_room_action_v160(uuid,text,text,integer,uuid) to authenticated;
create function public.aamix_trade_room_action(p_room uuid,p_action text,p_code text,p_revision integer,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.trade_room_action_v160(p_room,p_action,p_code,p_revision,p_request_id) $$;
revoke all on function public.aamix_trade_room_action(uuid,text,text,integer,uuid) from public,anon,authenticated;
grant execute on function public.aamix_trade_room_action(uuid,text,text,integer,uuid) to authenticated;
notify pgrst,'reload schema';
