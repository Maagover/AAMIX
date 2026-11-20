-- AAMIX 1.5: friendships, private invitations and atomic one-card swaps.
-- No account reset. All ownership comes from auth.uid(), never client-supplied identity.
create table aamix_private.social_people(
 user_id uuid primary key references auth.users(id) on delete cascade,
 friend_code text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),
 check(friend_code ~ '^[0-9A-F]{12}$')
);
create table aamix_private.friendships(
 low_id uuid not null references auth.users(id) on delete cascade,
 high_id uuid not null references auth.users(id) on delete cascade,
 sender uuid not null references auth.users(id) on delete cascade,
 status text not null check(status in('pending','accepted','declined')),
 updated_at timestamptz not null default now(),primary key(low_id,high_id),
 check(low_id<high_id and sender in(low_id,high_id))
);
create index friends_high_idx on aamix_private.friendships(high_id,status);
create table aamix_private.social_requests(
 user_id uuid not null references auth.users(id) on delete cascade,request_id uuid not null,
 kind text not null,payload jsonb not null,result jsonb not null,created_at timestamptz not null default now(),
 primary key(user_id,request_id)
);
create table aamix_private.card_trades(
 id uuid primary key default gen_random_uuid(),a_id uuid not null references auth.users(id) on delete cascade,
 b_id uuid not null references auth.users(id) on delete cascade,
 a_code text not null references aamix_private.catalog_codes(code),b_code text references aamix_private.catalog_codes(code),
 a_confirmed boolean not null default false,b_confirmed boolean not null default false,
 revision integer not null default 1 check(revision>0),status text not null default 'open' check(status in('open','completed','cancelled')),
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '24 hours',
 completed_at timestamptz,a_drafts jsonb not null default '[]',b_drafts jsonb not null default '[]',check(a_id<>b_id)
);
create index trades_a_idx on aamix_private.card_trades(a_id,status,created_at desc);
create index trades_b_idx on aamix_private.card_trades(b_id,status,created_at desc);
create table aamix_private.friend_duels(
 id uuid primary key default gen_random_uuid(),host_id uuid not null references auth.users(id) on delete cascade,
 guest_id uuid not null references auth.users(id) on delete cascade,
 room_id uuid not null references aamix_private.mp_rooms(id) on delete cascade,
 status text not null default 'pending' check(status in('pending','accepted','declined')),
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '10 minutes',check(host_id<>guest_id)
);
create index duels_guest_idx on aamix_private.friend_duels(guest_id,status);
alter table aamix_private.mp_rooms add column invited_user uuid references auth.users(id) on delete cascade;

alter table public.aamix_owned_decks add column draft boolean not null default false;
alter table public.aamix_owned_decks add column editable boolean not null default false;
alter table public.aamix_owned_decks add column revision integer not null default 1 check(revision>0);

alter table aamix_private.social_people enable row level security;
alter table aamix_private.friendships enable row level security;
alter table aamix_private.social_requests enable row level security;
alter table aamix_private.card_trades enable row level security;
alter table aamix_private.friend_duels enable row level security;
create policy social_people_server on aamix_private.social_people for all to anon,authenticated using(false) with check(false);
create policy friends_server on aamix_private.friendships for all to anon,authenticated using(false) with check(false);
create policy social_requests_server on aamix_private.social_requests for all to anon,authenticated using(false) with check(false);
create policy trades_server on aamix_private.card_trades for all to anon,authenticated using(false) with check(false);
create policy duels_server on aamix_private.friend_duels for all to anon,authenticated using(false) with check(false);
revoke all on aamix_private.social_people,aamix_private.friendships,aamix_private.social_requests,aamix_private.card_trades,aamix_private.friend_duels from public,anon,authenticated;

create function aamix_private.social_lock_pair(p_peer uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user();
begin
 if p_peer is null or p_peer=uid or not exists(select 1 from auth.users where id=p_peer and email_confirmed_at is not null and not coalesce(is_anonymous,false)) then raise exception 'AAMIX_FRIEND_UNAVAILABLE' using errcode='22023'; end if;
 insert into public.aamix_rewards_state(user_id) select x from unnest(array[uid,p_peer]) x order by x on conflict do nothing;
 perform 1 from public.aamix_rewards_state where user_id in(uid,p_peer) order by user_id for update;
 return uid;
end $$;
create function aamix_private.social_is_friend(p_a uuid,p_b uuid) returns boolean
language sql stable set search_path='' as $$ select exists(select 1 from aamix_private.friendships where low_id=least(p_a,p_b) and high_id=greatest(p_a,p_b) and status='accepted') $$;
create function aamix_private.social_peer(p_uid uuid) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('id',u.id,'name',left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),'Jugador'),24),
 'avatar_code',coalesce((select avatar_code from public.aamix_rewards_state where user_id=u.id),'')) from auth.users u where u.id=p_uid
$$;
create function aamix_private.social_replay(p_request uuid,p_kind text,p_payload jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare r aamix_private.social_requests%rowtype;
begin
 if p_request is null then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023'; end if;
 select * into r from aamix_private.social_requests where user_id=auth.uid() and request_id=p_request;
 if found then
  if r.kind<>p_kind or r.payload<>p_payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
  return r.result;
 end if;
 return null;
end $$;
create function aamix_private.trade_family(p_code text) returns text language sql stable set search_path='' as $$
 select case when is_promotional or card_class='Recurso' then null when is_singular then 'singular' else 'ordinary' end
 from aamix_private.reward_catalog where code=p_code
$$;
create function aamix_private.trade_available(p_uid uuid,p_code text,p_except uuid default null) returns integer
language sql stable set search_path='' as $$
 select greatest(0,coalesce((select quantity from public.aamix_collection where user_id=p_uid and code=p_code),0)
 -(select count(*)::integer from aamix_private.card_trades t where status='open' and expires_at>now() and id is distinct from p_except
 and ((a_id=p_uid and a_code=p_code) or (b_id=p_uid and b_code=p_code))))
$$;
create function aamix_private.social_inventory() returns jsonb language plpgsql security definer set search_path='' as $$
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
 return jsonb_build_object('user_id',uid,'friend_code',code,'friends',friends,'incoming',incoming,'outgoing',outgoing,'trades',trades,'duels',duels,'tradable_cards',cards);
end $$;
create function aamix_private.social_sync() returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user();
begin
 loop
  begin insert into aamix_private.social_people(user_id) values(uid) on conflict(user_id) do nothing; exit;
  exception when unique_violation then null; end;
 end loop;
 return aamix_private.social_inventory();
end $$;

create function aamix_private.friend_request(p_code text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid; peer uuid; normalized text:=upper(regexp_replace(coalesce(p_code,''),'[-[:space:]]','','g')); payload jsonb; replay jsonb; relation aamix_private.friendships%rowtype;
begin
 if normalized !~ '^[0-9A-F]{12}$' then raise exception 'AAMIX_FRIEND_UNAVAILABLE' using errcode='22023'; end if;
 select user_id into peer from aamix_private.social_people where friend_code=normalized;
 uid:=aamix_private.social_lock_pair(peer);payload:=jsonb_build_object('code',normalized);replay:=aamix_private.social_replay(p_request_id,'friend_request',payload);
 if replay is not null then return aamix_private.social_inventory(); end if;
 select * into relation from aamix_private.friendships where low_id=least(uid,peer) and high_id=greatest(uid,peer);
 if found and relation.status='pending' and relation.sender<>uid then
  update aamix_private.friendships set status='accepted',updated_at=now() where low_id=least(uid,peer) and high_id=greatest(uid,peer);
 elsif not found or relation.status='declined' then
  if found and relation.updated_at>now()-interval '1 minute' then raise exception 'AAMIX_SOCIAL_WAIT' using errcode='22023'; end if;
  if (select count(*) from aamix_private.friendships where sender=uid and status='pending')>=50 then raise exception 'AAMIX_SOCIAL_LIMIT' using errcode='22023'; end if;
  insert into aamix_private.friendships(low_id,high_id,sender,status) values(least(uid,peer),greatest(uid,peer),uid,'pending')
   on conflict(low_id,high_id) do update set sender=uid,status='pending',updated_at=now();
 end if;
 insert into aamix_private.social_requests values(uid,p_request_id,'friend_request',payload,'{}',now());
 return aamix_private.social_inventory();
end $$;
create function aamix_private.friend_respond(p_peer uuid,p_accept boolean,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.social_lock_pair(p_peer); payload jsonb:=jsonb_build_object('peer',p_peer,'accept',p_accept); replay jsonb; relation aamix_private.friendships%rowtype;
begin
 replay:=aamix_private.social_replay(p_request_id,'friend_respond',payload);if replay is not null then return aamix_private.social_inventory(); end if;
 select * into relation from aamix_private.friendships where low_id=least(uid,p_peer) and high_id=greatest(uid,p_peer) for update;
 if not found or relation.status<>'pending' or relation.sender=uid or p_accept is null then raise exception 'AAMIX_FRIEND_REQUEST_UNAVAILABLE' using errcode='22023'; end if;
 update aamix_private.friendships set status=case when p_accept then 'accepted' else 'declined' end,updated_at=now() where low_id=relation.low_id and high_id=relation.high_id;
 insert into aamix_private.social_requests values(uid,p_request_id,'friend_respond',payload,'{}',now());return aamix_private.social_inventory();
end $$;
create function aamix_private.friend_remove(p_peer uuid,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.social_lock_pair(p_peer);payload jsonb:=jsonb_build_object('peer',p_peer);replay jsonb;
begin
 replay:=aamix_private.social_replay(p_request_id,'friend_remove',payload);if replay is not null then return aamix_private.social_inventory(); end if;
 update aamix_private.friendships set status='declined',updated_at=now() where low_id=least(uid,p_peer) and high_id=greatest(uid,p_peer) and (status='accepted' or sender=uid);
 update aamix_private.card_trades set status='cancelled',revision=revision+1,a_confirmed=false,b_confirmed=false where status='open' and least(a_id,b_id)=least(uid,p_peer) and greatest(a_id,b_id)=greatest(uid,p_peer);
 insert into aamix_private.social_requests values(uid,p_request_id,'friend_remove',payload,'{}',now());return aamix_private.social_inventory();
end $$;

-- Clip only missing copies; the same owned copy may support multiple saved decks.
create function aamix_private.trade_trim_decks(p_uid uuid) returns jsonb language plpgsql set search_path='' as $$
declare d record; r record; clipped jsonb; changed jsonb:='[]';
begin
 for d in select deck_id,cards from public.aamix_custom_decks where user_id=p_uid for update loop
  select coalesce(jsonb_agg(jsonb_build_object('codigo',e->>'codigo','cantidad',least((e->>'cantidad')::integer,c.quantity)) order by e->>'codigo'),'[]') into clipped
   from jsonb_array_elements(d.cards) e join public.aamix_collection c on c.user_id=p_uid and c.code=e->>'codigo' where c.quantity>0;
  if clipped<>d.cards then update public.aamix_custom_decks set cards=clipped,draft=true,revision=revision+1,updated_at=now() where user_id=p_uid and deck_id=d.deck_id;changed:=changed||to_jsonb(d.deck_id);end if;
 end loop;
 for d in select deck_id,cards from public.aamix_owned_decks where user_id=p_uid for update loop
  select coalesce(jsonb_agg(jsonb_build_object('codigo',e->>'codigo','cantidad',least((e->>'cantidad')::integer,c.quantity)) order by e->>'codigo'),'[]') into clipped
   from jsonb_array_elements(d.cards) e join public.aamix_collection c on c.user_id=p_uid and c.code=e->>'codigo' where c.quantity>0;
  -- Compare canonical arrays; untouched original lists need no revision solely due to ordering.
  if clipped is distinct from (select jsonb_agg(e order by e->>'codigo') from jsonb_array_elements(d.cards) e) then
   update public.aamix_owned_decks set cards=clipped,draft=true,editable=true,revision=revision+1 where user_id=p_uid and deck_id=d.deck_id;changed:=changed||to_jsonb(d.deck_id);
  end if;
 end loop;
 update public.aamix_rewards_state set avatar_code=null where user_id=p_uid and avatar_code is not null and not exists(select 1 from public.aamix_collection where user_id=p_uid and code=avatar_code and quantity>0);
 -- Waiting rooms cannot begin with a newly invalid deck. Games already playing keep their frozen snapshot.
 if jsonb_array_length(changed)>0 then
  perform pg_advisory_xact_lock(170017,1);
  for r in select id from aamix_private.mp_rooms where status in('waiting','ready') and
   ((host_id=p_uid and changed ? (host_deck->>'id')) or (guest_id=p_uid and changed ? (guest_deck->>'id'))) order by id for update loop
   perform aamix_private.mp_finish(r.id,-1,'deck_changed_by_trade');
   update aamix_private.mp_rooms set revision=revision+1 where id=r.id;
  end loop;
 end if;
 return changed;
end $$;
create function aamix_private.trade_create(p_peer uuid,p_code text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.social_lock_pair(p_peer); payload jsonb:=jsonb_build_object('peer',p_peer,'code',p_code);replay jsonb; trade_id uuid;
begin
 replay:=aamix_private.social_replay(p_request_id,'trade_create',payload);
 if replay is not null then return aamix_private.social_inventory()||jsonb_build_object('trade_id',replay->>'trade_id');end if;
 if not aamix_private.social_is_friend(uid,p_peer) then raise exception 'AAMIX_NOT_FRIENDS' using errcode='42501';end if;
 if aamix_private.trade_family(p_code) is null then raise exception 'AAMIX_CARD_NOT_TRADABLE' using errcode='22023';end if;
 if aamix_private.trade_available(uid,p_code)<1 then raise exception 'AAMIX_TRADE_NO_COPY' using errcode='22023';end if;
 if (select count(*) from aamix_private.card_trades where uid in(a_id,b_id) and status='open' and expires_at>now())>=50 then raise exception 'AAMIX_SOCIAL_LIMIT' using errcode='22023';end if;
 insert into aamix_private.card_trades(a_id,b_id,a_code) values(uid,p_peer,p_code) returning id into trade_id;
 insert into aamix_private.social_requests values(uid,p_request_id,'trade_create',payload,jsonb_build_object('trade_id',trade_id),now());
 return aamix_private.social_inventory()||jsonb_build_object('trade_id',trade_id);
end $$;
create function aamix_private.trade_action(p_trade uuid,p_action text,p_code text,p_revision integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user(); peer uuid; t aamix_private.card_trades%rowtype; payload jsonb;replay jsonb; other_code text; drafts_a jsonb;drafts_b jsonb;
begin
 select * into t from aamix_private.card_trades where id=p_trade and uid in(a_id,b_id);
 if not found then raise exception 'AAMIX_TRADE_UNAVAILABLE' using errcode='42501';end if;
 peer:=case when t.a_id=uid then t.b_id else t.a_id end;perform aamix_private.social_lock_pair(peer);
 payload:=jsonb_build_object('trade',p_trade,'action',p_action,'code',p_code,'revision',p_revision);replay:=aamix_private.social_replay(p_request_id,'trade_action',payload);
 if replay is not null then return aamix_private.social_inventory()||jsonb_build_object('trade_id',p_trade,'inventory',public.aamix_inventory());end if;
 select * into strict t from aamix_private.card_trades where id=p_trade for update;
 if t.status<>'open' or t.expires_at<=now() then raise exception 'AAMIX_TRADE_CLOSED' using errcode='22023';end if;
 if p_revision is null or p_revision<>t.revision then raise exception 'AAMIX_TRADE_CHANGED' using errcode='40001';end if;
 if p_action='cancel' then
  update aamix_private.card_trades set status='cancelled',revision=revision+1,a_confirmed=false,b_confirmed=false where id=t.id;
 else
  if not aamix_private.social_is_friend(uid,peer) then raise exception 'AAMIX_NOT_FRIENDS' using errcode='42501';end if;
  if p_action='offer' then
   other_code:=case when uid=t.a_id then t.b_code else t.a_code end;
   if aamix_private.trade_family(p_code) is null then raise exception 'AAMIX_CARD_NOT_TRADABLE' using errcode='22023';end if;
   if other_code is not null and aamix_private.trade_family(p_code)<>aamix_private.trade_family(other_code) then raise exception 'AAMIX_TRADE_CATEGORY' using errcode='22023';end if;
   if aamix_private.trade_available(uid,p_code,t.id)<1 then raise exception 'AAMIX_TRADE_NO_COPY' using errcode='22023';end if;
   update aamix_private.card_trades set a_code=case when uid=a_id then p_code else a_code end,b_code=case when uid=b_id then p_code else b_code end,
    a_confirmed=false,b_confirmed=false,revision=revision+1 where id=t.id;
  elsif p_action='confirm' then
   if t.b_code is null then raise exception 'AAMIX_TRADE_INCOMPLETE' using errcode='22023';end if;
   if aamix_private.trade_family(t.a_code) is null or aamix_private.trade_family(t.a_code) is distinct from aamix_private.trade_family(t.b_code) then raise exception 'AAMIX_TRADE_CATEGORY' using errcode='22023';end if;
   if aamix_private.trade_available(t.a_id,t.a_code,t.id)<1 or aamix_private.trade_available(t.b_id,t.b_code,t.id)<1 then raise exception 'AAMIX_TRADE_NO_COPY' using errcode='22023';end if;
   update aamix_private.card_trades set a_confirmed=a_confirmed or uid=a_id,b_confirmed=b_confirmed or uid=b_id where id=t.id returning * into t;
   if t.a_confirmed and t.b_confirmed then
    if t.a_code<>t.b_code then
     delete from public.aamix_collection where ((user_id=t.a_id and code=t.a_code) or (user_id=t.b_id and code=t.b_code)) and quantity=1;
     update public.aamix_collection set quantity=quantity-1 where ((user_id=t.a_id and code=t.a_code) or (user_id=t.b_id and code=t.b_code));
     insert into public.aamix_collection(user_id,code,quantity) select t.a_id,t.b_code,1 union all select t.b_id,t.a_code,1
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+1;
    end if;
    drafts_a:=aamix_private.trade_trim_decks(t.a_id);drafts_b:=aamix_private.trade_trim_decks(t.b_id);
    update aamix_private.card_trades set status='completed',completed_at=now(),revision=revision+1,a_drafts=drafts_a,b_drafts=drafts_b where id=t.id;
   end if;
  else raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 end if;
 insert into aamix_private.social_requests values(uid,p_request_id,'trade_action',payload,jsonb_build_object('trade_id',p_trade),now());
 return aamix_private.social_inventory()||jsonb_build_object('trade_id',p_trade,'inventory',public.aamix_inventory());
end $$;

create function aamix_private.duel_create(p_peer uuid,p_deck text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.social_lock_pair(p_peer);payload jsonb:=jsonb_build_object('peer',p_peer,'deck',p_deck);replay jsonb; room jsonb;invitation uuid;
begin
 replay:=aamix_private.social_replay(p_request_id,'duel_create',payload);
 if replay is not null then return aamix_private.social_inventory()||jsonb_build_object('room',aamix_private.mp_response((replay->>'room_id')::uuid,uid));end if;
 if not aamix_private.social_is_friend(uid,p_peer) then raise exception 'AAMIX_NOT_FRIENDS' using errcode='42501';end if;
 room:=aamix_private.mp_create_room_v130(p_request_id,p_deck);
 update aamix_private.mp_rooms set invited_user=p_peer where id=(room->>'room_id')::uuid;
 insert into aamix_private.friend_duels(host_id,guest_id,room_id) values(uid,p_peer,(room->>'room_id')::uuid) returning id into invitation;
 insert into aamix_private.social_requests values(uid,p_request_id,'duel_create',payload,jsonb_build_object('room_id',room->>'room_id'),now());
 return aamix_private.social_inventory()||jsonb_build_object('room',room);
end $$;
create function aamix_private.duel_respond(p_invite uuid,p_accept boolean,p_deck text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.reward_user();d aamix_private.friend_duels%rowtype;r aamix_private.mp_rooms%rowtype;payload jsonb;replay jsonb;room jsonb;
begin
 select * into d from aamix_private.friend_duels where id=p_invite and guest_id=uid;
 if not found then raise exception 'AAMIX_INVITE_UNAVAILABLE' using errcode='42501';end if;
 perform aamix_private.social_lock_pair(d.host_id);payload:=jsonb_build_object('invite',p_invite,'accept',p_accept,'deck',p_deck);replay:=aamix_private.social_replay(p_request_id,'duel_respond',payload);
 if replay is not null then
  return aamix_private.social_inventory()||case when p_accept then jsonb_build_object('room',aamix_private.mp_response(d.room_id,uid)) else '{}'::jsonb end;
 end if;
 select * into strict d from aamix_private.friend_duels where id=p_invite for update;
 if d.status<>'pending' or d.expires_at<=now() or p_accept is null or not aamix_private.social_is_friend(uid,d.host_id) then raise exception 'AAMIX_INVITE_UNAVAILABLE' using errcode='22023';end if;
 select * into strict r from aamix_private.mp_rooms where id=d.room_id;
 if p_accept then room:=aamix_private.mp_join_room_v130(r.code,p_deck,p_request_id);
 else
  if r.status='waiting' then perform aamix_private.mp_finish(r.id,-1,'invite_declined');end if;
 end if;
 update aamix_private.friend_duels set status=case when p_accept then 'accepted' else 'declined' end where id=d.id;
 insert into aamix_private.social_requests values(uid,p_request_id,'duel_respond',payload,'{}',now());
 return aamix_private.social_inventory()||case when p_accept then jsonb_build_object('room',room) else '{}'::jsonb end;
end $$;





-- GENERATED EXTENSIONS
CREATE OR REPLACE FUNCTION aamix_private.mp_join_room_ruleset(p_code text, p_deck_id text, p_request_id uuid, p_ruleset_version text)
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
  if r.invited_user is not null and r.invited_user<>uid then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.aamix_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'draft',draft,'editable',editable,'revision',revision) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'custom_decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'custom',true,'draft',draft,'revision',revision) order by created_at,deck_id) from public.aamix_custom_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'kind',kind,'cards',cards,'new_card_indices',to_jsonb(new_card_indices),'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb))||aamix_private.deck_designs_inventory()||aamix_private.events_inventory();
end $function$
;
CREATE OR REPLACE FUNCTION aamix_private.mp_deck(p_uid uuid, p_deck_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owned public.aamix_owned_decks%rowtype; d jsonb; custom_row public.aamix_custom_decks%rowtype;
begin
  if p_uid is null or p_uid is distinct from auth.uid() then raise exception 'Authentication required' using errcode='28000'; end if;
  select jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards)
    into d from public.aamix_owned_decks where user_id=p_uid and deck_id=p_deck_id;
  if d is not null then
    select * into strict owned from public.aamix_owned_decks where user_id=p_uid and deck_id=p_deck_id;
    if owned.draft then raise exception 'AAMIX_DECK_DRAFT' using errcode='22023'; end if;
    perform aamix_private.custom_cards(p_uid,owned.cards,false);
    if (select coalesce(sum((e->>'cantidad')::integer),0) from jsonb_array_elements(d->'cartas')e)<>40 then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
    return d||jsonb_build_object('draft',owned.draft,'editable',owned.editable,'revision',owned.revision);
  end if;
  select * into custom_row from public.aamix_custom_decks where user_id=p_uid and deck_id=p_deck_id;
  if not found then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
  if custom_row.draft then raise exception 'AAMIX_DECK_DRAFT' using errcode='22023'; end if;
  perform aamix_private.custom_cards(p_uid,custom_row.cards,false);
  return jsonb_build_object('id',custom_row.deck_id,'nombre',custom_row.name,'portada',custom_row.cover,'recurso_inicial','0100','cartas',custom_row.cards,'custom',true,'draft',false,'revision',custom_row.revision);
end $function$
;

create function aamix_private.save_repaired_deck(p_request_id uuid,p_deck_id text,p_nombre text,p_portada text,p_cartas jsonb,p_draft boolean,p_expected_revision integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards();d public.aamix_owned_decks%rowtype;old aamix_private.custom_deck_requests%rowtype;payload jsonb;saved jsonb;canonical jsonb;title text:=btrim(p_nombre);
begin
 if p_request_id is null or p_expected_revision is null or p_expected_revision<1 or p_draft is null or title is null or char_length(title) not between 1 and 48 or title ~ '[[:cntrl:]]' then raise exception 'AAMIX_INVALID_DECK' using errcode='22023';end if;
 payload:=jsonb_build_object('id',p_deck_id,'nombre',title,'portada',p_portada,'cartas',p_cartas,'draft',p_draft,'expected_revision',p_expected_revision);
 select * into old from aamix_private.custom_deck_requests where user_id=uid and request_id=p_request_id;
 if found then
  if old.payload<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023';end if;
  return public.aamix_inventory()||jsonb_build_object('saved_deck',old.saved_deck,'last_saved_deck',old.saved_deck);
 end if;
 select * into d from public.aamix_owned_decks where user_id=uid and deck_id=p_deck_id for update;
 if not found or not d.editable then raise exception 'AAMIX_DECK_IMMUTABLE' using errcode='22023';end if;
 if p_portada is distinct from d.cover then raise exception 'AAMIX_INVALID_DECK_COVER' using errcode='22023';end if;
 if p_expected_revision<>d.revision then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001';end if;
 canonical:=aamix_private.custom_cards(uid,p_cartas,p_draft);
 update public.aamix_owned_decks set cards=canonical,name=title,draft=p_draft,revision=revision+1 where user_id=uid and deck_id=p_deck_id returning * into d;
 saved:=jsonb_build_object('id',d.deck_id,'nombre',d.name,'portada',d.cover,'cartas',d.cards,'draft',d.draft,'editable',true,'custom',false,'revision',d.revision,'recurso_inicial','0100');
 insert into aamix_private.custom_deck_requests values(uid,p_request_id,payload,saved,now());
 return public.aamix_inventory()||jsonb_build_object('saved_deck',saved,'last_saved_deck',saved);
end $$;
revoke all on function aamix_private.save_repaired_deck(uuid,text,text,text,jsonb,boolean,integer) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION aamix_private.save_custom_deck(p_request_id uuid, p_deck_id text, p_nombre text, p_portada text, p_cartas jsonb, p_draft boolean, p_expected_revision integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); d public.aamix_custom_decks%rowtype;
  old_request aamix_private.custom_deck_requests%rowtype; payload jsonb; saved jsonb; canonical_cards jsonb;
  normalized_id text:=coalesce(p_deck_id,''); normalized_name text:=btrim(p_nombre);
begin
  if normalized_id<>'' and normalized_id not like 'custom_%' then return aamix_private.save_repaired_deck(p_request_id,p_deck_id,p_nombre,p_portada,p_cartas,p_draft,p_expected_revision);end if;
  if p_request_id is null or p_expected_revision is null or p_expected_revision<0 or p_draft is null
    or normalized_name is null or char_length(normalized_name) not between 1 and 48 or normalized_name ~ '[[:cntrl:]]'
    or p_portada is null or p_portada not in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin','custom_kajido')
    or p_cartas is null or octet_length(p_cartas::text)>8192 then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
  payload:=jsonb_build_object('id',normalized_id,'nombre',normalized_name,'portada',p_portada,'cartas',p_cartas,'draft',p_draft,'expected_revision',p_expected_revision);
  select * into old_request from aamix_private.custom_deck_requests where user_id=uid and request_id=p_request_id;
  if found then
    if old_request.payload<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return public.aamix_inventory()||jsonb_build_object('saved_deck',old_request.saved_deck,'last_saved_deck',old_request.saved_deck);
  end if;
  if p_portada not in('custom_transmision','custom_restos') and not exists(
    select 1 from public.aamix_code_redemptions redeemed
    where redeemed.user_id=uid and redeemed.deck_design=p_portada
  ) and not exists(select 1 from aamix_private.event_design_unlocks earned where earned.user_id=uid and earned.design=p_portada) then raise exception 'AAMIX_DECK_COVER_LOCKED' using errcode='22023'; end if;
  canonical_cards:=aamix_private.custom_cards(uid,p_cartas,p_draft);
  if normalized_id='' then
    if p_expected_revision<>0 then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001'; end if;
    normalized_id:='custom_'||gen_random_uuid()::text;
    insert into aamix_private.deck_registry(id) values(normalized_id);
    insert into public.aamix_custom_decks(user_id,deck_id,name,cover,cards,draft)
      values(uid,normalized_id,normalized_name,p_portada,canonical_cards,p_draft) returning * into d;
  else
    if normalized_id !~ '^custom_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'AAMIX_DECK_IMMUTABLE' using errcode='22023'; end if;
    select * into d from public.aamix_custom_decks where user_id=uid and deck_id=normalized_id for update;
    if not found then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
    if d.revision<>p_expected_revision then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001'; end if;
    update public.aamix_custom_decks set name=normalized_name,cover=p_portada,cards=canonical_cards,draft=p_draft,revision=revision+1,updated_at=now()
      where user_id=uid and deck_id=normalized_id returning * into d;
  end if;
  saved:=jsonb_build_object('id',d.deck_id,'nombre',d.name,'portada',d.cover,'recurso_inicial','0100','cartas',d.cards,'custom',true,'draft',d.draft,'revision',d.revision);
  insert into aamix_private.custom_deck_requests(user_id,request_id,payload,saved_deck) values(uid,p_request_id,payload,saved);
  return public.aamix_inventory()||jsonb_build_object('saved_deck',saved,'last_saved_deck',saved);
end $function$
;
revoke all on function aamix_private.social_lock_pair(uuid) from public,anon,authenticated;
revoke all on function aamix_private.social_is_friend(uuid,uuid) from public,anon,authenticated;
revoke all on function aamix_private.social_peer(uuid) from public,anon,authenticated;
revoke all on function aamix_private.social_replay(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function aamix_private.trade_family(text) from public,anon,authenticated;
revoke all on function aamix_private.trade_available(uuid,text,uuid) from public,anon,authenticated;
revoke all on function aamix_private.trade_trim_decks(uuid) from public,anon,authenticated;
revoke all on function aamix_private.social_inventory() from public,anon,authenticated;
revoke all on function aamix_private.social_sync() from public,anon,authenticated;
grant execute on function aamix_private.social_sync() to authenticated;
create function public.aamix_social_sync() returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.social_sync() $$;
revoke all on function public.aamix_social_sync() from public,anon,authenticated;
grant execute on function public.aamix_social_sync() to authenticated;
revoke all on function aamix_private.friend_request(text,uuid) from public,anon,authenticated;
grant execute on function aamix_private.friend_request(text,uuid) to authenticated;
create function public.aamix_friend_request(p_code text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.friend_request(p_code,p_request_id) $$;
revoke all on function public.aamix_friend_request(text,uuid) from public,anon,authenticated;
grant execute on function public.aamix_friend_request(text,uuid) to authenticated;
revoke all on function aamix_private.friend_respond(uuid,boolean,uuid) from public,anon,authenticated;
grant execute on function aamix_private.friend_respond(uuid,boolean,uuid) to authenticated;
create function public.aamix_friend_respond(p_peer uuid,p_accept boolean,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.friend_respond(p_peer,p_accept,p_request_id) $$;
revoke all on function public.aamix_friend_respond(uuid,boolean,uuid) from public,anon,authenticated;
grant execute on function public.aamix_friend_respond(uuid,boolean,uuid) to authenticated;
revoke all on function aamix_private.friend_remove(uuid,uuid) from public,anon,authenticated;
grant execute on function aamix_private.friend_remove(uuid,uuid) to authenticated;
create function public.aamix_friend_remove(p_peer uuid,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.friend_remove(p_peer,p_request_id) $$;
revoke all on function public.aamix_friend_remove(uuid,uuid) from public,anon,authenticated;
grant execute on function public.aamix_friend_remove(uuid,uuid) to authenticated;
revoke all on function aamix_private.trade_create(uuid,text,uuid) from public,anon,authenticated;
grant execute on function aamix_private.trade_create(uuid,text,uuid) to authenticated;
create function public.aamix_trade_create(p_peer uuid,p_code text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.trade_create(p_peer,p_code,p_request_id) $$;
revoke all on function public.aamix_trade_create(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.aamix_trade_create(uuid,text,uuid) to authenticated;
revoke all on function aamix_private.trade_action(uuid,text,text,integer,uuid) from public,anon,authenticated;
grant execute on function aamix_private.trade_action(uuid,text,text,integer,uuid) to authenticated;
create function public.aamix_trade_action(p_trade uuid,p_action text,p_code text,p_revision integer,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.trade_action(p_trade,p_action,p_code,p_revision,p_request_id) $$;
revoke all on function public.aamix_trade_action(uuid,text,text,integer,uuid) from public,anon,authenticated;
grant execute on function public.aamix_trade_action(uuid,text,text,integer,uuid) to authenticated;
revoke all on function aamix_private.duel_create(uuid,text,uuid) from public,anon,authenticated;
grant execute on function aamix_private.duel_create(uuid,text,uuid) to authenticated;
create function public.aamix_duel_create(p_peer uuid,p_deck text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.duel_create(p_peer,p_deck,p_request_id) $$;
revoke all on function public.aamix_duel_create(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.aamix_duel_create(uuid,text,uuid) to authenticated;
revoke all on function aamix_private.duel_respond(uuid,boolean,text,uuid) from public,anon,authenticated;
grant execute on function aamix_private.duel_respond(uuid,boolean,text,uuid) to authenticated;
create function public.aamix_duel_respond(p_invite uuid,p_accept boolean,p_deck text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select aamix_private.duel_respond(p_invite,p_accept,p_deck,p_request_id) $$;
revoke all on function public.aamix_duel_respond(uuid,boolean,text,uuid) from public,anon,authenticated;
grant execute on function public.aamix_duel_respond(uuid,boolean,text,uuid) to authenticated;
notify pgrst,'reload schema';
