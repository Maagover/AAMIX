begin;
-- Synthetic transaction only. Run after both proposed migrations, then ROLLBACK.
create temp table qa_results(name text primary key,ok boolean not null);
create function pg_temp.qa(ok boolean,label text) returns void language plpgsql as $$ begin
 if ok is distinct from true then raise exception 'QA FAILED: %',label; end if;
 insert into qa_results values(label,true);
end $$;
create function pg_temp.denied(command text,expected text,label text) returns void language plpgsql as $$
begin
 begin execute command; exception when others then
  if sqlerrm=expected then perform pg_temp.qa(true,label); return; end if;
  raise exception 'QA unexpected error for %: %',label,sqlerrm;
 end;
 raise exception 'QA unexpectedly allowed: %',label;
end $$;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();j jsonb;k jsonb;t uuid;rid uuid;invite uuid;req uuid;custom text;cover text;before_wallet jsonb;receipt uuid;
begin
 insert into auth.users(id,aud,role,email,email_confirmed_at,raw_user_meta_data,raw_app_meta_data,created_at,updated_at)
 select x,'authenticated','authenticated','qa-social-v150-'||x||'@example.invalid',now(),jsonb_build_object('display_name','Prueba social'),'{"provider":"email","providers":["email"]}',now(),now() from unnest(array[a,b,c]) x;
 insert into public.aamix_rewards_state(user_id) select x from unnest(array[a,b,c]) x;
 insert into public.aamix_collection(user_id,code,quantity) select x,'0100',40 from unnest(array[a,b,c]) x;
 insert into public.aamix_collection values(a,'0101',1),(a,'0102',2),(a,'0105',1),(a,'01a',1),(b,'0104',1),(b,'0128',1),(b,'0103',1),(c,'0101',1);
 select d.cover into cover from aamix_private.base_decks d where id='kajido';
 insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
 select x,'kajido','Mazo Kajido',cover,jsonb_build_array(jsonb_build_object('codigo','0100','cantidad',39),jsonb_build_object('codigo',case when x=a then '0101' else '0104' end,'cantidad',1)) from unnest(array[a,b]) x;
 perform set_config('request.jwt.claim.sub',a::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 j:=public.aamix_social_sync();
 perform pg_temp.qa(j->>'user_id'=a::text and length(j->>'friend_code')=12 and jsonb_array_length(j->'friends')=0,'own stable code');
 perform pg_temp.qa(public.aamix_social_sync()->>'friend_code'=j->>'friend_code','code stable on reconnect');
 perform pg_temp.denied(format('select public.aamix_friend_request(%L,gen_random_uuid())',j->>'friend_code'),'AAMIX_FRIEND_UNAVAILABLE','cannot add self');
 perform pg_temp.denied(format('select public.aamix_trade_create(%L,''0101'',gen_random_uuid())',b),'AAMIX_NOT_FRIENDS','cannot trade before friendship');
 perform set_config('request.jwt.claim.sub',b::text,true);k:=public.aamix_social_sync();
 perform set_config('request.jwt.claim.sub',a::text,true);req:=gen_random_uuid();j:=public.aamix_friend_request(k->>'friend_code',req);
 perform pg_temp.qa(jsonb_array_length(j->'outgoing')=1,'send friend request');
 j:=public.aamix_friend_request(k->>'friend_code',req);perform pg_temp.qa(jsonb_array_length(j->'outgoing')=1,'request retry idempotent');
 perform set_config('request.jwt.claim.sub',b::text,true);j:=public.aamix_social_sync();perform pg_temp.qa(jsonb_array_length(j->'incoming')=1 and position('@' in j::text)=0,'incoming request without email');
 j:=public.aamix_friend_respond(a,true,gen_random_uuid());perform pg_temp.qa(jsonb_array_length(j->'friends')=1,'accept friendship');
 perform set_config('request.jwt.claim.sub',c::text,true);j:=public.aamix_social_sync();perform pg_temp.qa(jsonb_array_length(j->'friends')=0 and jsonb_array_length(j->'trades')=0,'third account isolated');
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform pg_temp.denied(format('select public.aamix_trade_create(%L,''0100'',gen_random_uuid())',b),'AAMIX_CARD_NOT_TRADABLE','Resources excluded');
 perform pg_temp.denied(format('select public.aamix_trade_create(%L,''01a'',gen_random_uuid())',b),'AAMIX_CARD_NOT_TRADABLE','Promos excluded');
 req:=gen_random_uuid();j:=public.aamix_trade_create(b,'0101',req);t:=(j->>'trade_id')::uuid;
 perform pg_temp.qa(public.aamix_trade_create(b,'0101',req)->>'trade_id'=t::text,'offer retry idempotent');
 perform pg_temp.denied(format('select public.aamix_trade_create(%L,''0101'',gen_random_uuid())',b),'AAMIX_TRADE_NO_COPY','open offer reserves copy');
 perform set_config('request.jwt.claim.sub',c::text,true);
 perform pg_temp.denied(format('select public.aamix_trade_action(%L,''cancel'','''',1,gen_random_uuid())',t),'AAMIX_TRADE_UNAVAILABLE','third account cannot mutate trade');
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform pg_temp.denied(format('select public.aamix_trade_action(%L,''offer'',''0103'',1,gen_random_uuid())',t),'AAMIX_TRADE_CATEGORY','Singular mismatched rejected');
 j:=public.aamix_trade_action(t,'offer','0128',1,gen_random_uuid());
 perform pg_temp.qa((select b_code='0128' and revision=2 from aamix_private.card_trades where id=t),'Special exchanges with Normal');
 perform public.aamix_trade_action(t,'confirm','',2,gen_random_uuid());
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform public.aamix_trade_action(t,'offer','0102',2,gen_random_uuid());
 perform pg_temp.qa((select not a_confirmed and not b_confirmed and revision=3 from aamix_private.card_trades where id=t),'changed card clears both confirmations');
 perform pg_temp.denied(format('select public.aamix_trade_action(%L,''confirm'','''',2,gen_random_uuid())',t),'AAMIX_TRADE_CHANGED','stale offer confirmation rejected');
 perform public.aamix_trade_action(t,'offer','0101',3,gen_random_uuid());
 -- Create a custom deck, plus a frozen active single-player receipt before giving away its last copy.
 j:=public.aamix_save_custom_deck(gen_random_uuid(),'','Prueba personalizada','custom_restos','[{"codigo":"0100","cantidad":39},{"codigo":"0101","cantidad":1}]',false,0);
 custom:=j->'saved_deck'->>'id';
 j:=public.aamix_begin_match(gen_random_uuid(),'kajido');receipt:=(j->>'match_id')::uuid;
 j:=public.aamix_duel_create(b,'kajido',gen_random_uuid());rid:=(j->'room'->>'room_id')::uuid;
 perform pg_temp.qa(rid is not null and (select invited_user=b from aamix_private.mp_rooms where id=rid),'battle invitation targets friend');
 perform set_config('request.jwt.claim.sub',c::text,true);
 perform pg_temp.denied(format('select aamix_private.mp_join_room_v130(%L,''kajido'',gen_random_uuid())',(select code from aamix_private.mp_rooms where id=rid)),'AAMIX_ROOM_FORBIDDEN','invited room denies outsider');
 perform set_config('request.jwt.claim.sub',a::text,true);
 req:=gen_random_uuid();j:=public.aamix_trade_action(t,'confirm','',4,req);
 perform pg_temp.qa(exists(select 1 from public.aamix_collection where user_id=a and code='0101' and quantity=1),'one confirmation does not transfer');
 perform set_config('request.jwt.claim.sub',b::text,true);j:=public.aamix_trade_action(t,'confirm','',4,gen_random_uuid());
 perform pg_temp.qa((select status='completed' from aamix_private.card_trades where id=t) and not exists(select 1 from public.aamix_collection where user_id=a and code='0101') and (select quantity=1 from public.aamix_collection where user_id=b and code='0101') and (select quantity=1 from public.aamix_collection where user_id=a and code='0128'),'atomic transfer and conservation');
 perform pg_temp.qa((select draft and editable and revision=2 and jsonb_array_length(cards)=1 from public.aamix_owned_decks where user_id=a and deck_id='kajido'),'base deck clips lost copy and becomes editable draft');
 perform pg_temp.qa((select draft and revision=2 and jsonb_array_length(cards)=1 from public.aamix_custom_decks where user_id=a and deck_id=custom),'custom deck clips lost copy and becomes draft');
 perform pg_temp.qa((select status='cancelled' from aamix_private.mp_rooms where id=rid),'waiting room cancelled after loss');
 perform pg_temp.qa(exists(select 1 from public.aamix_match_receipts where match_id=receipt and player_deck->'cartas' @> '[{"codigo":"0101","cantidad":1}]'),'already started match snapshot preserved');
 perform set_config('request.jwt.claim.sub',a::text,true);j:=public.aamix_trade_action(t,'confirm','',4,req);
 perform pg_temp.qa((select quantity=1 from public.aamix_collection where user_id=a and code='0128'),'final confirmation retry does not duplicate');
 perform pg_temp.denied(format('select aamix_private.mp_deck(%L,''kajido'')',a),'AAMIX_DECK_DRAFT','draft cannot start match');
 j:=public.aamix_save_custom_deck(gen_random_uuid(),'kajido','Kajido reparado',cover,'[{"codigo":"0100","cantidad":39},{"codigo":"0128","cantidad":1}]',false,2);
 perform pg_temp.qa(not (j->'saved_deck'->>'draft')::boolean and (j->'saved_deck'->>'editable')::boolean and j->'saved_deck'->>'portada'=cover,'repair base deck to playable 40 preserving cover');
 perform pg_temp.denied(format('select public.aamix_save_custom_deck(gen_random_uuid(),''kajido'',''Sin Recurso'',%L,''[{"codigo":"0128","cantidad":1}]'',true,3)',cover),'AAMIX_DECK_INITIAL_RESOURCE','repaired draft still needs Resource');
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform pg_temp.denied(format('select public.aamix_save_custom_deck(gen_random_uuid(),''kajido'',''No tocado'',%L,''[{"codigo":"0100","cantidad":40}]'',false,1)',cover),'AAMIX_DECK_IMMUTABLE','untouched base remains immutable');
 -- A spare owned copy can leave without invalidating an otherwise complete deck.
 perform set_config('request.jwt.claim.sub',a::text,true);j:=public.aamix_trade_create(b,'0102',gen_random_uuid());t:=(j->>'trade_id')::uuid;
 perform set_config('request.jwt.claim.sub',b::text,true);perform public.aamix_trade_action(t,'offer','0104',1,gen_random_uuid());perform public.aamix_trade_action(t,'confirm','',2,gen_random_uuid());
 perform set_config('request.jwt.claim.sub',a::text,true);perform public.aamix_trade_action(t,'confirm','',2,gen_random_uuid());
 perform pg_temp.qa((select quantity=1 from public.aamix_collection where user_id=a and code='0102') and (select not draft and revision=3 from public.aamix_owned_decks where user_id=a and deck_id='kajido'),'spare copy transfer preserves unrelated deck');
 -- Invitation acceptance uses existing lobby confirmation; declined requests close cleanly.
 j:=public.aamix_duel_create(b,'kajido',gen_random_uuid());rid:=(j->'room'->>'room_id')::uuid;
 select id into invite from aamix_private.friend_duels where room_id=rid;
 perform set_config('request.jwt.claim.sub',b::text,true);
 -- B's base lost its Javieriv above: repair it before accepting.
 j:=public.aamix_save_custom_deck(gen_random_uuid(),'kajido','Reparado B',cover,'[{"codigo":"0100","cantidad":39},{"codigo":"0101","cantidad":1}]',false,2);
 j:=public.aamix_duel_respond(invite,true,'kajido',gen_random_uuid());
 perform pg_temp.qa(j->'room'->>'status'='ready' and (select guest_id=b from aamix_private.mp_rooms where id=rid),'friend accepts battle into existing lobby');
 perform aamix_private.mp_leave(rid);
 -- New missions count stored receipts, including prior games, independently per account.
 insert into public.aamix_match_receipts(user_id,request_id,deck_id,player_deck,finished_at,result)
 select a,gen_random_uuid(),'kajido','{"id":"kajido","cartas":[{"codigo":"0105","cantidad":1},{"codigo":"0103","cantidad":1},{"codigo":"0115","cantidad":1}]}',now(),'victory' from generate_series(1,50);
 perform set_config('request.jwt.claim.sub',a::text,true);j:=aamix_private.historical_status_v150();
 perform pg_temp.qa(jsonb_array_length(j)=5 and (select bool_and((v->>'progress')::int=(v->>'target')::int) from jsonb_array_elements(j) v),'five historical objectives count frozen starting decks');
 perform aamix_private.ensure_restos_welcome();select jsonb_build_object('packs',packs,'normal',normal_packs,'restos',restos) into before_wallet from public.aamix_rewards_state where user_id=a;
 for k in select value from jsonb_array_elements(j) loop
  perform public.aamix_claim_mission(k->>'id');perform public.aamix_claim_mission(k->>'id');
 end loop;
 perform pg_temp.qa((select packs=(before_wallet->>'packs')::int+7 and normal_packs=(before_wallet->>'normal')::int+10 and restos=(before_wallet->>'restos')::bigint+600 from public.aamix_rewards_state where user_id=a),'exact historical rewards granted once across retries');
 perform set_config('request.jwt.claim.sub',c::text,true);
 perform pg_temp.denied('select public.aamix_claim_mission(''play_fifty'')','AAMIX_MISSION_NOT_READY','historical reward isolated by UUID');
 perform pg_temp.qa((select count(*)=5 from aamix_private.historical_claims_v150 where user_id=a) and not exists(select 1 from aamix_private.historical_claims_v150 where user_id=c),'claim ledger isolated');
 perform set_config('request.jwt.claim.sub',a::text,true);
 j:=public.aamix_trade_create(b,'0105',gen_random_uuid());t:=(j->>'trade_id')::uuid;
 perform set_config('request.jwt.claim.sub',b::text,true);perform public.aamix_trade_action(t,'offer','0103',1,gen_random_uuid());perform public.aamix_trade_action(t,'confirm','',2,gen_random_uuid());
 perform set_config('request.jwt.claim.sub',a::text,true);perform public.aamix_trade_action(t,'confirm','',2,gen_random_uuid());
 perform pg_temp.qa((select quantity=1 from public.aamix_collection where user_id=a and code='0103') and (select quantity=1 from public.aamix_collection where user_id=b and code='0105'),'Singular for Singular allowed');
 j:=public.aamix_trade_create(b,'0102',gen_random_uuid());t:=(j->>'trade_id')::uuid;
 perform public.aamix_trade_action(t,'cancel','',1,gen_random_uuid());
 perform pg_temp.qa(aamix_private.trade_available(a,'0102')=1,'cancel releases reserved copy');
 j:=public.aamix_duel_create(b,'kajido',gen_random_uuid());rid:=(j->'room'->>'room_id')::uuid;select id into invite from aamix_private.friend_duels where room_id=rid;
 perform set_config('request.jwt.claim.sub',b::text,true);perform public.aamix_duel_respond(invite,false,'',gen_random_uuid());
 perform pg_temp.qa((select status='cancelled' from aamix_private.mp_rooms where id=rid),'decline battle closes waiting room');
 perform set_config('request.jwt.claim.sub',a::text,true);j:=public.aamix_trade_create(b,'0102',gen_random_uuid());t:=(j->>'trade_id')::uuid;req:=gen_random_uuid();
 perform public.aamix_friend_remove(b,req);perform public.aamix_friend_remove(b,req);
 perform pg_temp.qa(not aamix_private.social_is_friend(a,b) and (select status='cancelled' from aamix_private.card_trades where id=t),'remove friend cancels pending trades idempotently');
 perform pg_temp.qa(not has_function_privilege('anon','public.aamix_trade_create(uuid,text,uuid)','execute') and not has_table_privilege('authenticated','aamix_private.card_trades','select'),'anonymous and direct table access denied');
 perform pg_temp.qa(not has_function_privilege('authenticated','aamix_private.trade_trim_decks(uuid)','execute'),'internal transfer helper inaccessible');
end $$;
select count(*) checks,bool_and(ok) passed,jsonb_agg(name order by name) cases from qa_results;

rollback;
