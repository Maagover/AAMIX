-- 23 bounded assertions; deterministic draws are confined to this rollback.
begin;
set local plpgsql.check_asserts=on;
create temporary table qa018(label text primary key,uid uuid default gen_random_uuid());
insert into qa018(label) values('host'),('guest'),('legacy'),('outsider'),('unconfirmed');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
 select uid,uid::text||'@qa-v018.invalid',case when label='unconfirmed' then null else now() end,now(),now(),false from qa018;
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
 select q.uid,d.id,d.name,d.cover,d.cards from qa018 q cross join aamix_private.base_decks d where d.id='papito';
select set_config('qa.host',(select uid::text from qa018 where label='host'),true);
select set_config('qa.guest',(select uid::text from qa018 where label='guest'),true);
select set_config('qa.legacy',(select uid::text from qa018 where label='legacy'),true);
select set_config('qa.outsider',(select uid::text from qa018 where label='outsider'),true);
select set_config('qa.unconfirmed',(select uid::text from qa018 where label='unconfirmed'),true);
insert into public.aamix_rewards_state(user_id,restos,packs,normal_packs)
 select uid,100,2,1 from qa018;
insert into public.aamix_restos_welcome(user_id) select uid from qa018;
insert into public.aamix_collection(user_id,code,quantity) select uid,'0100',1 from qa018 where label='host';
insert into public.aamix_collection(user_id,code,quantity) select uid,'0101',1 from qa018 where label='guest';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,finished_at,result)
 select uid,gen_random_uuid(),'papito',now(),'victory' from qa018 where label in('host','legacy');
insert into public.aamix_daily_claims_v016(user_id,mission_id,mission_day,completed_match_id,reward_kind,reward_amount)
 select q.uid,'play_one',(now() at time zone 'America/Santiago')::date,r.match_id,'restos',50 from qa018 q join public.aamix_match_receipts r on r.user_id=q.uid where q.label='legacy';
update public.aamix_rewards_state set restos=150 where user_id=(select uid from qa018 where label='legacy');
-- Exact draws isolate first-new-copy and repeated-card handling without samples.
create or replace function aamix_private.draw_pack() returns jsonb language sql security definer set search_path='' as $$select '["0100","0101","0101","0104","0105"]'::jsonb;$$;
create or replace function aamix_private.draw_normal_card() returns jsonb language sql security definer set search_path='' as $$select '["0101"]'::jsonb;$$;
select set_config('qa.h','{"players":[{"deck":[4],"hand":[3]},{"deck":[6],"hand":[5]}],"instances":{"1":{"code":"0100"},"2":{"code":"0100"},"3":{"code":"0115"},"4":{"code":"0103"},"5":{"code":"0107"},"6":{"code":"0105"}},"actor":0,"winner":-1,"queue":[],"log_lines":[],"rng_seed":"123","rng_state":"456","pending":{}}',true);
select set_config('qa.g','{"players":[{"deck":[-1000],"hand":[-1100]},{"deck":[-1200],"hand":[5]}],"instances":{"1":{"code":"0100"},"2":{"code":"0100"},"5":{"code":"0107"}},"actor":0,"winner":-1,"queue":[],"log_lines":[],"rng_seed":"0","rng_state":"0","pending":{}}',true);
set local role authenticated;
do $$
declare r jsonb; g jsonb; x jsonb; h jsonb:=current_setting('qa.h')::jsonb; v jsonb:=current_setting('qa.g')::jsonb;
 rid uuid; code text; req uuid:=gen_random_uuid(); opening_req uuid:=gen_random_uuid(); initial uuid:=gen_random_uuid(); action uuid:=gen_random_uuid(); rejected integer; caught boolean;
begin
 assert not has_function_privilege('anon','public.aamix_mp_confirm(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.aamix_mp_host_action(uuid,uuid,integer,text,jsonb,jsonb,jsonb,integer,integer,text)','EXECUTE')
  and not (select prosecdef from pg_proc where oid='public.aamix_mp_confirm(uuid)'::regprocedure)
  and not has_table_privilege('authenticated','aamix_private.mp_rooms','SELECT'),'01 authenticated invoker endpoints and private room storage';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.host'),'role','authenticated')::text,true);
 r:=public.aamix_inventory();
 assert r->'missions'->0->>'reward_amount'='25' and r->'missions'->1->>'reward_amount'='1'
  and r->'missions'->2->>'reward_amount'='3' and r->'missions'->3->>'reward_amount'='5','02 four mission rewards, only daily play is 25';
 r:=public.aamix_claim_mission('play_one');
 assert r->>'restos'='125' and r->>'reward_amount'='25' and r->>'packs'='2' and r->>'normal_packs'='1','03 new daily claim awards exactly 25';
 r:=public.aamix_claim_daily_mission();
 assert r->>'already_claimed'='true' and r->>'restos'='125' and r->>'reward_amount'='25','04 legacy endpoint retry cannot pay twice';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.legacy'),'role','authenticated')::text,true);
 r:=public.aamix_claim_mission('play_one');
 assert r->>'already_claimed'='true' and r->>'restos'='150' and r->>'reward_amount'='50','05 historical 50 reward is preserved and reported accurately';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.host'),'role','authenticated')::text,true);
 r:=public.aamix_open_pack(opening_req);
 assert r->'opening'->'cards'='["0100","0101","0101","0104","0105"]'::jsonb and r->'opening'->'new_card_indices'='[1,3,4]'::jsonb,
  '06 known resource unmarked, first duplicate new only once, other unseen cards marked';
 assert r->'collection'->>'0100'='2' and r->'collection'->>'0101'='2' and r->>'packs'='1','07 metadata changes no quantities or pack cost';
 x:=public.aamix_open_normal_pack(opening_req);
 assert x->'opening'=r->'opening' and x->>'packs'='1' and x->>'normal_packs'='1','08 cross-kind request retry returns identical new markers and ordered cards';
 x:=public.aamix_inventory();
 assert x->'pending_opening'->'new_card_indices'='[1,3,4]'::jsonb,'09 pending opening retains original new flags after inventory reload';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.guest'),'role','authenticated')::text,true);
 x:=public.aamix_open_normal_pack(gen_random_uuid());
 assert x->'opening'->'new_card_indices'='[]'::jsonb and x->'opening'->'cards'='["0101"]'::jsonb and x->>'normal_packs'='0','10 owned normal-card packet has no false new badge';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.host'),'role','authenticated')::text,true);
 r:=public.aamix_mp_create_room(req,'papito'); rid:=(r->>'room_id')::uuid;code:=r->>'code';
 assert r->'confirmed'='[false,false]'::jsonb and r->>'protocol'='2' and r->>'revision'='0','11 new room starts unconfirmed';
 r:=public.aamix_mp_confirm(rid);
 assert r->'confirmed'='[true,false]'::jsonb and r->>'status'='waiting' and r->'state'='null'::jsonb,'12 host can confirm while waiting without null guest state';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.guest'),'role','authenticated')::text,true);
 g:=public.aamix_mp_join_room(code,'papito',gen_random_uuid());
 assert g->'confirmed'='[true,false]'::jsonb and g->>'status'='ready' and g->'state'='null'::jsonb,'13 joining alone does not start the match';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.host'),'role','authenticated')::text,true);
 caught:=false;begin perform public.aamix_mp_commit(rid,initial,0,h,v,0);exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_CONFIRM_REQUIRED';end;
 assert caught and public.aamix_mp_poll(rid,-1)->>'revision'='0','14 server rejects start before both confirmations';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.outsider'),'role','authenticated')::text,true);
 rejected:=0;begin perform public.aamix_mp_confirm(rid);exception when sqlstate '42501' then rejected:=rejected+1;end;
 begin perform public.aamix_mp_host_action(rid,action,0,'keep_hand','[]',h,v,0);exception when sqlstate '42501' then rejected:=rejected+1;end;
 assert rejected=2,'15 nonmember cannot confirm or use fast host action';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.guest'),'role','authenticated')::text,true);
 g:=public.aamix_mp_confirm(rid);x:=public.aamix_mp_confirm(rid);
 assert g->'confirmed'='[true,true]'::jsonb and x->>'revision'='0','16 confirmation retry is idempotent and waits for initial commit';
 caught:=false;begin perform public.aamix_mp_host_action(rid,action,0,'keep_hand','[]',h,v,0);exception when sqlstate '42501' then caught:=true;end;
 assert caught,'17 guest cannot act as host even after confirming';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.host'),'role','authenticated')::text,true);
 r:=public.aamix_mp_commit(rid,initial,0,h,v,0);
 assert r->>'revision'='1' and r->>'status'='playing','18 confirmed start commits exactly once';
 caught:=false;begin perform public.aamix_mp_host_action(rid,action,1,'keep_hand','[]',h,jsonb_set(v,'{instances,3}','{"code":"0115"}'),0);exception when sqlstate '22023' then caught:=true;end;
 r:=public.aamix_mp_poll(rid,-1);
 assert caught and r->>'revision'='1' and r->'commands'='[]'::jsonb,'19 invalid combined snapshot rolls back its submitted command too';
 h:=jsonb_set(h,'{actor}','1');v:=jsonb_set(v,'{actor}','1');
 r:=public.aamix_mp_host_action(rid,action,1,'keep_hand','[]',h,v,1);
 x:=public.aamix_mp_host_action(rid,action,1,'keep_hand','[]',h,v,1);
 assert r->>'revision'='2' and x->>'revision'='2' and x->'commands'='[]'::jsonb,'20 one-call host action and uncertain-response retry advance only once';
 x:=public.aamix_mp_poll(rid,2);
 assert not(x?'state') and not(x?'host_deck') and not(x->'players'->0?'deck'),'21 unchanged host poll omits snapshot and both full decks';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.guest'),'role','authenticated')::text,true);
 g:=public.aamix_mp_poll(rid,-1);
 assert g->'state'=v and not(g?'commands') and not(g?'host_deck') and not(g->'players'->0?'deck'),'22 guest still receives only its own filtered snapshot';
 r:=public.aamix_mp_leave(rid);x:=public.aamix_mp_leave(rid);
 assert r->>'winner'='0' and x->>'winner'='0' and r->>'status'='finished'
  and (select count(*) from public.aamix_match_receipts where online_room_id=rid)=1,'23 abandon retry creates one immutable result for this owner';
end $$;
reset role;
rollback;
select jsonb_build_object('checks',23,'failures',0,'all_fixtures_rolled_back',true,'real_players_touched',0,'deterministic_pack_draw_fixtures',true) as v018_server_checks;
