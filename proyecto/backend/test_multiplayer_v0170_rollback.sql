-- 25 focused cases. No AI simulation, no real accounts, complete rollback.
begin;
set local plpgsql.check_asserts=on;
create temporary table qa017_mp(label text primary key,uid uuid not null default gen_random_uuid());
insert into qa017_mp(label) values('host'),('guest'),('outsider'),('unconfirmed');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous,raw_user_meta_data)
  select uid,uid::text||'@qa-mp-v017.invalid',case when label='unconfirmed' then null else now() end,now(),now(),false,
    jsonb_build_object('display_name','QA '||label) from qa017_mp;
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select q.uid,d.id,d.name,d.cover,d.cards from qa017_mp q cross join aamix_private.base_decks d where d.id in('papito','flaan');
select set_config('qa.mp.host',(select uid::text from qa017_mp where label='host'),true);
select set_config('qa.mp.guest',(select uid::text from qa017_mp where label='guest'),true);
select set_config('qa.mp.outsider',(select uid::text from qa017_mp where label='outsider'),true);
select set_config('qa.mp.unconfirmed',(select uid::text from qa017_mp where label='unconfirmed'),true);
select set_config('qa.mp.h','{"players":[{"deck":[4],"hand":[3]},{"deck":[6],"hand":[5]}],"instances":{"1":{"code":"0100"},"2":{"code":"0100"},"3":{"code":"0115"},"4":{"code":"0103"},"5":{"code":"0107"},"6":{"code":"0105"}},"actor":0,"winner":-1,"queue":[],"log_lines":[],"rng_seed":"123","rng_state":"456","pending":{}}',true);
select set_config('qa.mp.g','{"players":[{"deck":[-1000],"hand":[-3000]},{"deck":[-1100],"hand":[5]}],"instances":{"1":{"code":"0100"},"2":{"code":"0100"},"5":{"code":"0107"},"-1000":{"code":"0100"},"-1100":{"code":"0100"},"-3000":{"code":"0100"}},"actor":0,"winner":-1,"queue":[],"log_lines":[],"rng_seed":"0","rng_state":"0","pending":{}}',true);
set local role authenticated;
do $$
declare r jsonb; g jsonb; p jsonb; h jsonb:=current_setting('qa.mp.h')::jsonb; v jsonb:=current_setting('qa.mp.g')::jsonb;
  initial uuid:=gen_random_uuid(); create_id uuid:=gen_random_uuid(); join_id uuid:=gen_random_uuid(); action_id uuid:=gen_random_uuid();
  next_id uuid; rid uuid; caught boolean; rejected integer; old_count integer;
begin
  assert (select bool_and(relrowsecurity) from pg_class where oid in('aamix_private.mp_rooms'::regclass,'aamix_private.mp_members'::regclass,'aamix_private.mp_commands'::regclass))
    and not has_table_privilege('authenticated','aamix_private.mp_rooms','SELECT') and not has_table_privilege('authenticated','aamix_private.mp_commands','INSERT')
    and not has_function_privilege('anon','public.aamix_mp_create_room(uuid,text)','EXECUTE')
    and not has_function_privilege('authenticated','aamix_private.mp_response(uuid,uuid,integer)','EXECUTE')
    and not exists(select 1 from pg_proc where oid in('public.aamix_mp_create_room(uuid,text)'::regprocedure,'public.aamix_mp_commit(uuid,uuid,integer,jsonb,jsonb,integer,integer,text)'::regprocedure) and prosecdef),
    '01 private tables RLS, no direct reads/writes, guarded invoker endpoints';
  rejected:=0;
  perform set_config('request.jwt.claims','{}',true);
  begin perform public.aamix_mp_active(); exception when sqlstate '28000' then rejected:=rejected+1; end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.unconfirmed'),'role','authenticated')::text,true);
  begin perform public.aamix_mp_create_room(create_id,'papito'); exception when sqlstate '28000' then rejected:=rejected+1; end;
  assert rejected=2,'02 anonymous and unconfirmed identities rejected';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_mp_create_room(create_id,'girabl'); exception when sqlstate '22023' then caught:=true; end;
  assert caught,'03 only owned exact 40-card decks accepted';
  r:=public.aamix_mp_create_room(create_id,'papito'); rid:=(r->>'room_id')::uuid;
  perform set_config('qa.mp.room',rid::text,true);
  perform set_config('qa.mp.code',r->>'code',true);
  assert r->>'status'='waiting' and r->>'slot'='0' and r->>'code'~'^[0-9A-F]{8}$' and r->'players'->0->'deck'->>'id'='papito' and r->>'winner'='-1',
    '04 private cryptographic room code, role and immutable owned-deck snapshot';
  caught:=false; begin perform public.aamix_mp_create_room(create_id,'flaan'); exception when sqlstate '22023' then caught:=true; end;
  assert public.aamix_mp_create_room(create_id,'papito')->>'room_id'=rid::text and caught,'05 create idempotency and UUID payload immutability';
  rejected:=0;
  begin perform public.aamix_mp_create_room(gen_random_uuid(),'flaan'); exception when sqlstate '22023' then rejected:=rejected+1; end;
  begin perform public.aamix_mp_join_room(r->>'code','flaan',gen_random_uuid()); exception when sqlstate '22023' then rejected:=rejected+1; end;
  assert rejected=2 and public.aamix_mp_active()->>'room_id'=rid::text,'06 one active room per account, no self join, reconnect lookup';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.outsider'),'role','authenticated')::text,true);
  rejected:=0;
  begin perform public.aamix_mp_poll(rid,-1); exception when sqlstate '42501' then rejected:=rejected+1; end;
  begin perform public.aamix_mp_commit(rid,initial,0,h,v,0); exception when sqlstate '42501' then rejected:=rejected+1; end;
  assert rejected=2,'07 room UUID alone grants no read or commit access';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.guest'),'role','authenticated')::text,true);
  g:=public.aamix_mp_join_room(lower(r->>'code'),'flaan',join_id);
  assert g->>'status'='ready' and g->>'slot'='1' and g->>'revision'='0' and not(g?'host_deck') and not(g->'players'->0?'deck') and not(g?'commands'),
    '08 guest joins once and receives no full decks, host state or command queue';
  caught:=false; begin perform public.aamix_mp_join_room(r->>'code','papito',join_id); exception when sqlstate '22023' then caught:=true; end;
  assert public.aamix_mp_join_room(r->>'code','flaan',join_id)->>'room_id'=rid::text and caught,'09 join idempotency and deck immutability';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  p:=public.aamix_mp_poll(rid,0);
  assert p->>'status'='ready' and not(p?'state') and p->'guest_deck'->>'id'='flaan' and p->'commands'='[]'::jsonb,'10 unchanged polls omit snapshot but include bounded host command queue';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.guest'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_mp_commit(rid,initial,0,h,v,0); exception when sqlstate '42501' then caught:=true; end;
  assert caught,'11 guest cannot commit authoritative snapshots or outcomes';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  rejected:=0;
  begin perform public.aamix_mp_commit(rid,initial,0,h,jsonb_set(v,'{instances,3}','{"code":"0115"}'),0); exception when sqlstate '22023' then rejected:=rejected+1; end;
  begin perform public.aamix_mp_commit(rid,initial,0,h,jsonb_set(v,'{players,0,hand}','[3]'),0); exception when sqlstate '22023' then rejected:=rejected+1; end;
  assert rejected=2,'12 redacted view rejects hidden true UID instances and real opponent hand IDs';
  r:=public.aamix_mp_commit(rid,initial,0,h,v,0);
  assert r->>'status'='playing' and r->>'revision'='1' and r->'state'=h and public.aamix_mp_commit(rid,initial,0,h,v,0)->>'revision'='1',
    '13 initial start and retry are atomic, full host state remains recoverable';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.guest'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_mp_submit(rid,action_id,1,'keep_hand','[]'); exception when sqlstate '42501' then caught:=true; end;
  assert caught and public.aamix_mp_poll(rid,-1)->'state'=v,'14 out-of-turn command rejected, guest receives only its redacted view';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  rejected:=0;
  begin perform public.aamix_mp_submit(rid,action_id,0,'keep_hand','[]'); exception when sqlstate '40001' then rejected:=rejected+1; end;
  begin perform public.aamix_mp_submit(rid,action_id,1,'new_game','[]'); exception when sqlstate '22023' then rejected:=rejected+1; end;
  begin perform public.aamix_mp_submit(rid,action_id,1,'choose','["secret"]'); exception when sqlstate '22023' then rejected:=rejected+1; end;
  assert rejected=3,'15 stale revisions, non-game methods and string command payloads rejected';
  r:=public.aamix_mp_submit(rid,action_id,1,'keep_hand','[]');
  caught:=false; begin perform public.aamix_mp_submit(rid,action_id,1,'mulligan','[]'); exception when sqlstate '22023' then caught:=true; end;
  assert caught and jsonb_array_length(r->'commands')=1 and public.aamix_mp_submit(rid,action_id,1,'keep_hand','[]')->>'command_status'='pending',
    '16 action UUID is immutable and retry does not duplicate command';
  caught:=false; begin perform public.aamix_mp_submit(rid,gen_random_uuid(),1,'mulligan','[]'); exception when sqlstate '55000' then caught:=true; end;
  assert caught,'17 at most one pending action per revision';
  caught:=false; begin perform public.aamix_mp_commit(rid,gen_random_uuid(),1,h,v,0); exception when sqlstate '22023' then caught:=true; end;
  assert caught,'18 host cannot mutate running state without consuming a matching action';
  h:=jsonb_set(h,'{actor}','1'); v:=jsonb_set(v,'{actor}','1');
  r:=public.aamix_mp_commit(rid,action_id,1,h,v,1);
  assert r->>'revision'='2' and r->'commands'='[]'::jsonb and public.aamix_mp_commit(rid,action_id,1,h,v,1)->>'revision'='2'
    and not(public.aamix_mp_poll(rid,2)?'state'),'19 committed action advances once, atomically clears queue and supports retry';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.guest'),'role','authenticated')::text,true);
  next_id:=gen_random_uuid(); g:=public.aamix_mp_submit(rid,next_id,2,'keep_hand','[]');
  assert not(g?'commands') and g->>'command_status'='pending','20 guest submits allowed command without observing relay queue';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_mp_commit(rid,next_id,2,jsonb_set(h,'{actor}','0'),v,0,-1,'AAMIX_INVALID_ACTION'); exception when sqlstate '22023' then caught:=true; end;
  r:=public.aamix_mp_commit(rid,next_id,2,h,v,1,-1,'AAMIX_INVALID_ACTION');
  assert caught and r->>'revision'='3' and r->'state'=h and r->>'last_error'='AAMIX_INVALID_ACTION' and r->'commands'='[]'::jsonb,
    '21 invalid game action is rejected without state mutation and unblocks queue';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.guest'),'role','authenticated')::text,true);
  next_id:=gen_random_uuid(); perform public.aamix_mp_submit(rid,next_id,3,'finish_turn','[]');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  h:=jsonb_set(h,'{winner}','1'); v:=jsonb_set(v,'{winner}','1');
  r:=public.aamix_mp_commit(rid,next_id,3,h,v,1,1);
  perform public.aamix_mp_commit(rid,next_id,3,h,v,1,1);
  perform public.aamix_mp_leave(rid);
  select count(*) into old_count from public.aamix_match_receipts where online_room_id=rid and result='defeat';
  caught:=false; begin perform public.aamix_finish_match((select match_id from public.aamix_match_receipts where online_room_id=rid),'victory'); exception when others then caught:=true; end;
  assert r->>'status'='finished' and r->>'winner'='1' and old_count=1 and caught and public.aamix_mp_active()->'room_id'='null'::jsonb,
    '22 terminal room creates one immutable finished receipt per player; repeats cannot inflate missions';
  r:=public.aamix_mp_create_room(gen_random_uuid(),'papito');
  p:=public.aamix_mp_leave((r->>'room_id')::uuid);
  assert p->>'status'='cancelled' and not exists(select 1 from public.aamix_match_receipts where online_room_id=(r->>'room_id')::uuid)
    and public.aamix_mp_active()->'room_id'='null'::jsonb,'23 leaving before start cancels with no mission receipt and frees occupancy';
end $$;
reset role;
-- Reuse only the synthetic participants to exercise bounded disconnect and TTL.
do $$
declare r jsonb; rid uuid;
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  r:=public.aamix_mp_create_room(gen_random_uuid(),'papito'); rid:=(r->>'room_id')::uuid;
  perform set_config('qa.mp.disconnect',rid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.guest'),'role','authenticated')::text,true);
  perform public.aamix_mp_join_room(r->>'code','papito',gen_random_uuid());
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.mp.host'),'role','authenticated')::text,true);
  perform public.aamix_mp_commit(rid,gen_random_uuid(),0,current_setting('qa.mp.h')::jsonb,current_setting('qa.mp.g')::jsonb,0);
  update aamix_private.mp_rooms set guest_seen=now()-interval '181 seconds' where id=rid;
end $$;
set local role authenticated;
do $$
declare r jsonb; rid uuid:=current_setting('qa.mp.disconnect')::uuid;
begin
  r:=public.aamix_mp_poll(rid,-1);
  perform public.aamix_mp_poll(rid,-1);
  assert r->>'status'='finished' and r->>'winner'='0' and r->>'finish_reason'='disconnected' and
    (select count(*) from public.aamix_match_receipts where online_room_id=rid)=1,'24 peer disconnect grace expires once, poll retry gives one receipt';
end $$;
reset role;
do $$
declare r jsonb;
begin
  r:=public.aamix_mp_create_room(gen_random_uuid(),'papito');
  perform set_config('qa.mp.expired',r->>'room_id',true);
  update aamix_private.mp_rooms set expires_at=now()-interval '1 second' where id=(r->>'room_id')::uuid;
end $$;
set local role authenticated;
do $$
declare r jsonb; rid uuid:=current_setting('qa.mp.expired')::uuid;
begin
  r:=public.aamix_mp_poll(rid,-1);
  assert r->>'status'='cancelled' and r->>'finish_reason'='expired' and not exists(select 1 from public.aamix_match_receipts where online_room_id=rid)
    and public.aamix_mp_active()->'room_id'='null'::jsonb,'25 hard TTL releases room and cannot manufacture a completed game';
end $$;
reset role;
select jsonb_build_object('checks',25,'failures',0,'real_players_touched',0,'all_fixtures_rolled_back',true) as multiplayer_v017_result;
rollback;
