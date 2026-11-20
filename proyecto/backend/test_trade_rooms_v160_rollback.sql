-- Predeployment rehearsal: concatenate proposed aamix_trade_rooms_v160.sql then this file inside BEGIN/ROLLBACK. Do not rerun the migration on production.
-- Run with the proposed migration in one transaction and ROLLBACK.
create temp table qa_results(name text primary key,ok boolean not null);
create function pg_temp.qa(ok boolean,label text) returns void language plpgsql as $$ begin
 if ok is distinct from true then raise exception 'QA FAILED: %',label;end if;insert into qa_results values(label,true);end $$;
create function pg_temp.denied(command text,expected text,label text) returns void language plpgsql as $$ begin
 begin execute command;exception when others then
  if sqlerrm=expected then perform pg_temp.qa(true,label);return;end if;
  raise exception 'QA unexpected error for %: %',label,sqlerrm;
 end;raise exception 'QA unexpectedly allowed: %',label;end $$;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();j jsonb;r uuid;req uuid;custom text;cover text;
begin
 insert into auth.users(id,aud,role,email,email_confirmed_at,raw_user_meta_data,raw_app_meta_data,created_at,updated_at)
 select x,'authenticated','authenticated','qa-rooms-v160-'||x||'@example.invalid',now(),'{"display_name":"Prueba de sala"}','{"provider":"email","providers":["email"]}',now(),now() from unnest(array[a,b,c]) x;
 insert into public.aamix_rewards_state(user_id) select x from unnest(array[a,b,c]) x;
 insert into public.aamix_collection values(a,'0100',40),(b,'0100',40),(c,'0100',40),(a,'0101',1),(a,'0105',1),(a,'01a',1),(b,'0128',1),(b,'0103',1),(c,'0101',1);
 insert into aamix_private.friendships(low_id,high_id,sender,status)
 select least(x,y),greatest(x,y),x,'accepted' from (values(a,b),(a,c),(b,c)) q(x,y);
 select d.cover into cover from aamix_private.base_decks d where id='kajido';
 insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
 select x,'kajido','Mazo Kajido',cover,jsonb_build_array(jsonb_build_object('codigo','0100','cantidad',39),jsonb_build_object('codigo',case when x=a then '0101' else '0128' end,'cantidad',1)) from unnest(array[a,b]) x;
 perform set_config('request.jwt.claim.sub',a::text,true);
 j:=public.aamix_social_sync();perform pg_temp.qa(j->'trade_room'='{}','No phantom room');
 perform pg_temp.qa(not exists(select 1 from aamix_private.card_trades where status='open'),'Old uncompleted reservations retired');
 perform pg_temp.denied(format('select public.aamix_trade_create(%L,''0101'',gen_random_uuid())',b),'AAMIX_TRADE_UPDATE_REQUIRED','Old client cannot bypass new room');
 req:=gen_random_uuid();j:=public.aamix_trade_room_create(b,req);r:=(j->'trade_room'->>'id')::uuid;
 perform pg_temp.qa(j->'trade_room'->>'status'='invited' and j->'trade_room'->>'role'='host','Invite creates waiting room');
 perform pg_temp.qa(public.aamix_trade_room_create(b,req)->'trade_room'->>'id'=r::text,'Invite retry idempotent');
 perform pg_temp.denied(format('select public.aamix_trade_room_create(%L,gen_random_uuid())',c),'AAMIX_ALREADY_TRADING','Host cannot open a second room');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''offer'',''0101'',1,gen_random_uuid())',r),'AAMIX_TRADE_NOT_CONNECTED','Cannot offer before friend enters');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''accept'','''',1,gen_random_uuid())',r),'AAMIX_TRADE_TURN','Inviter cannot accept own invitation');
 perform set_config('request.jwt.claim.sub',c::text,true);
 perform pg_temp.denied(format('select public.aamix_trade_room_create(%L,gen_random_uuid())',b),'AAMIX_ALREADY_TRADING','Invited player cannot be in another room');
 perform pg_temp.denied(format('select public.aamix_trade_room_poll(%L)',r),'AAMIX_TRADE_UNAVAILABLE','Third UUID cannot view room');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''cancel'','''',1,gen_random_uuid())',r),'AAMIX_TRADE_UNAVAILABLE','Third UUID cannot cancel room');
 perform set_config('request.jwt.claim.sub',b::text,true);j:=public.aamix_social_sync();
 perform pg_temp.qa(j->'trade_room'->>'id'=r::text and j->'trade_room'->>'role'='guest' and position('@' in (j->'trade_room')::text)=0,'Friend sees invitation without email');
 j:=public.aamix_trade_room_action(r,'accept','',1,gen_random_uuid());
 perform pg_temp.qa(j->'trade_room'->>'status'='host_offer' and (j->'trade_room'->>'host_connected')::boolean and (j->'trade_room'->>'guest_connected')::boolean,'Accept enters connected room with host first');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''offer'',''0128'',2,gen_random_uuid())',r),'AAMIX_TRADE_TURN','Guest must wait for host choice');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''confirm'','''',2,gen_random_uuid())',r),'AAMIX_TRADE_INCOMPLETE','Cannot confirm before both choices');
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''offer'',''0100'',2,gen_random_uuid())',r),'AAMIX_CARD_NOT_TRADABLE','Resource rejected');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''offer'',''01a'',2,gen_random_uuid())',r),'AAMIX_CARD_NOT_TRADABLE','Promotional rejected');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''offer'',''0106'',2,gen_random_uuid())',r),'AAMIX_TRADE_NO_COPY','Unowned card rejected');
 j:=public.aamix_trade_room_action(r,'offer','0101',2,gen_random_uuid());
 perform pg_temp.qa(j->'trade_room'->>'status'='guest_offer' and j->'trade_room'->>'own_code'='0101' and aamix_private.trade_available(a,'0101')=0,'Host choice creates sole reserved offer');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''offer'',''0105'',3,gen_random_uuid())',r),'AAMIX_TRADE_TURN','Host cannot add another offer');
 j:=public.aamix_save_custom_deck(gen_random_uuid(),'','Mazo de prueba','custom_restos','[{"codigo":"0100","cantidad":39},{"codigo":"0101","cantidad":1}]',false,0);custom:=j->'saved_deck'->>'id';
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''offer'',''0103'',3,gen_random_uuid())',r),'AAMIX_TRADE_CATEGORY','Singular cannot answer Normal');
 j:=public.aamix_trade_room_action(r,'offer','0128',3,gen_random_uuid());
 perform pg_temp.qa(j->'trade_room'->>'status'='confirming' and j->'trade_room'->>'own_code'='0128' and j->'trade_room'->>'peer_code'='0101','Special answers Normal and enables final pair');
 perform set_config('request.jwt.claim.sub',a::text,true);perform public.aamix_trade_room_action(r,'confirm','',4,gen_random_uuid());
 perform pg_temp.qa((select quantity=1 from public.aamix_collection where user_id=a and code='0101'),'One confirmation never transfers');
 update aamix_private.trade_rooms_v160 set a_seen=clock_timestamp()-interval '21 seconds' where id=r;
 perform set_config('request.jwt.claim.sub',b::text,true);j:=public.aamix_trade_room_poll(r);
 perform pg_temp.qa(not (j->'trade_room'->>'own_confirmed')::boolean and not (j->'trade_room'->>'peer_confirmed')::boolean and (j->'trade_room'->>'revision')::int=5,'Disconnect clears previous confirmations');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''confirm'','''',5,gen_random_uuid())',r),'AAMIX_TRADE_NOT_CONNECTED','Disconnected peer blocks transfer');
 perform set_config('request.jwt.claim.sub',a::text,true);j:=public.aamix_trade_room_poll(r);
 perform pg_temp.qa((j->'trade_room'->>'host_connected')::boolean and j->'trade_room'->>'own_code'='0101','Reconnect preserves sole offered pair');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''confirm'','''',4,gen_random_uuid())',r),'AAMIX_TRADE_CHANGED','Stale confirmation rejected');
 perform public.aamix_trade_room_action(r,'confirm','',5,gen_random_uuid());
 perform set_config('request.jwt.claim.sub',b::text,true);req:=gen_random_uuid();j:=public.aamix_trade_room_action(r,'confirm','',5,req);
 perform pg_temp.qa(j->'trade_room'->>'status'='completed' and not (j->'trade_room'->>'active')::boolean and not exists(select 1 from aamix_private.trade_members_v160 where room_id=r),'Both confirmations complete and release room');
 perform pg_temp.qa(not exists(select 1 from public.aamix_collection where user_id=a and code='0101') and (select quantity=1 from public.aamix_collection where user_id=b and code='0101') and (select quantity=1 from public.aamix_collection where user_id=a and code='0128') and not exists(select 1 from public.aamix_collection where user_id=b and code='0128'),'Atomic exchange conserves exact copies');
 perform pg_temp.qa((select draft and editable and revision=2 from public.aamix_owned_decks where user_id=a and deck_id='kajido') and (select draft and revision=2 from public.aamix_custom_decks where user_id=a and deck_id=custom),'Lost copies turn base and custom into editable drafts');
 perform pg_temp.qa((select draft and editable from public.aamix_owned_decks where user_id=b and deck_id='kajido'),'Other participant base also becomes editable draft');
 perform public.aamix_trade_room_action(r,'confirm','',5,req);
 perform pg_temp.qa((select quantity=1 from public.aamix_collection where user_id=b and code='0101'),'Final retry cannot duplicate');
 perform pg_temp.denied(format('select public.aamix_trade_room_action(%L,''cancel'','''',5,%L)',r,req),'AAMIX_REQUEST_REUSED','Same UUID with different payload rejected');
 perform set_config('request.jwt.claim.sub',a::text,true);j:=public.aamix_trade_room_poll(r);
 perform pg_temp.qa(j->'inventory'->'collection'->>'0128'='1' and j->'trade_room'->>'status'='completed','Peer recovers completion inventory on next poll');
 j:=public.aamix_save_custom_deck(gen_random_uuid(),'kajido','Reparado',cover,'[{"codigo":"0100","cantidad":39},{"codigo":"0128","cantidad":1}]',false,2);
 perform pg_temp.qa(not (j->'saved_deck'->>'draft')::boolean,'Affected base can be repaired');
 j:=public.aamix_trade_room_create(b,gen_random_uuid());r:=(j->'trade_room'->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',b::text,true);perform public.aamix_trade_room_action(r,'accept','',1,gen_random_uuid());
 perform set_config('request.jwt.claim.sub',a::text,true);perform public.aamix_trade_room_action(r,'offer','0105',2,gen_random_uuid());
 perform set_config('request.jwt.claim.sub',b::text,true);perform public.aamix_trade_room_action(r,'offer','0103',3,gen_random_uuid());perform public.aamix_trade_room_action(r,'confirm','',4,gen_random_uuid());
 perform set_config('request.jwt.claim.sub',a::text,true);perform public.aamix_trade_room_action(r,'confirm','',4,gen_random_uuid());
 perform pg_temp.qa((select quantity=1 from public.aamix_collection where user_id=a and code='0103') and (select quantity=1 from public.aamix_collection where user_id=b and code='0105'),'Singular for Singular exchanges successfully');
 j:=public.aamix_trade_room_create(b,gen_random_uuid());r:=(j->'trade_room'->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',b::text,true);perform public.aamix_trade_room_action(r,'cancel','',1,gen_random_uuid());
 perform pg_temp.qa((select status='cancelled' from aamix_private.trade_rooms_v160 where id=r) and not exists(select 1 from aamix_private.trade_members_v160 where user_id in(a,b)),'Reject invitation releases both participants');
 perform set_config('request.jwt.claim.sub',a::text,true);j:=public.aamix_trade_room_create(b,gen_random_uuid());r:=(j->'trade_room'->>'id')::uuid;
 update aamix_private.trade_rooms_v160 set expires_at=clock_timestamp()-interval '1 second' where id=r;j:=public.aamix_trade_room_poll(r);
 perform pg_temp.qa(j->'trade_room'->>'status'='expired' and not exists(select 1 from aamix_private.trade_members_v160 where room_id=r),'Expired room releases reservations and membership');
 j:=public.aamix_trade_room_create(b,gen_random_uuid());r:=(j->'trade_room'->>'id')::uuid;
 perform public.aamix_friend_remove(b,gen_random_uuid());j:=public.aamix_trade_room_poll(r);
 perform pg_temp.qa(j->'trade_room'->>'close_reason'='friend_removed' and not exists(select 1 from aamix_private.trade_members_v160 where room_id=r),'Removing friendship cancels live invitation');
 perform pg_temp.qa(not has_function_privilege('anon','public.aamix_trade_room_create(uuid,uuid)','execute') and not has_table_privilege('authenticated','aamix_private.trade_rooms_v160','select'),'Anonymous and direct room access denied');
 perform pg_temp.qa(not has_function_privilege('authenticated','aamix_private.trade_room_cleanup_v160(uuid)','execute'),'Privileged cleanup helper inaccessible');
end $$;
select count(*) checks,bool_and(ok) passed,jsonb_agg(name order by name) cases from qa_results;
