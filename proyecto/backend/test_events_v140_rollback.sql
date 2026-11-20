-- Run after the migration inside the SAME transaction; never retain the QA clock.
set local plpgsql.check_asserts=on;
create temporary table qa140_users(label text primary key,uid uuid default gen_random_uuid());
insert into qa140_users(label) values('a'),('b');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
 select uid,uid::text||'@qa-v140.invalid',now(),now(),now(),false from qa140_users;
select set_config('qa140.a',(select uid::text from qa140_users where label='a'),true);
select set_config('qa140.b',(select uid::text from qa140_users where label='b'),true);
insert into public.aamix_collection(user_id,code,quantity) select uid,'0100',40 from qa140_users;
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-10-21 00:00:00 America/Santiago'::timestamptz $$;
set local role authenticated;
do $$
declare r jsonb; base jsonb; retry jsonb; blocked boolean; req uuid:=gen_random_uuid();
begin
 assert not has_function_privilege('anon','public.aamix_events_sync()','EXECUTE')
  and not has_table_privilege('authenticated','aamix_private.event_claims','INSERT')
  and not has_table_privilege('authenticated','aamix_private.event_design_unlocks','UPDATE')
  and not has_function_privilege('authenticated','aamix_private.event_clock()','EXECUTE'),'01 server-only clock and reward ledgers';
 perform set_config('request.jwt.claims','{}',true);
 blocked:=false; begin perform public.aamix_events_sync(); exception when sqlstate '28000' then blocked:=true; end;
 assert blocked,'02 unauthenticated sync rejected';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa140.a'),'role','authenticated')::text,true);
 base:=public.aamix_inventory();
 assert base->'events'->0->>'id'='bienvenida_2026' and base->'events'->0->'missions'->0->>'progress'='0','03 inclusive start, read alone is not login';
 r:=public.aamix_events_sync(); retry:=public.aamix_events_sync();
 assert r->'events'->0->'missions'->0->>'progress'='1' and r->'events'=retry->'events','04 verified daily login stable';
 r:=public.aamix_claim_event_mission('bienvenida_2026','login'); retry:=public.aamix_claim_event_mission('bienvenida_2026','login');
 assert r->>'restos'='25' and retry->>'restos'='25' and retry->>'already_claimed'='true','05 daily claim exactly once';
 blocked:=false; begin perform public.aamix_claim_event_mission('bienvenida_2026','play_one'); exception when sqlstate '22023' then blocked:=sqlerrm='AAMIX_MISSION_NOT_READY'; end;
 assert blocked,'06 uncompleted mission rejected';
 r:=public.aamix_redeem_code(' bienvenidAA '); retry:=public.aamix_redeem_code('BIENVENIDAA');
 assert r->>'reward_packs'='1' and r->>'reward_normal_packs'='1' and r->>'reward_restos'='100'
  and retry->>'already_redeemed'='true' and retry->>'restos'=r->>'restos','07 timed bundle exact and idempotent with welcome award preserved';
 blocked:=false; begin perform public.aamix_redeem_code('GATONEGRO'); exception when sqlstate '22023' then blocked:=sqlerrm='AAMIX_CODE_INACTIVE'; end;
 assert blocked,'08 future event code rejected';
 blocked:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Sin recurso','custom_restos','[]',true,0); exception when sqlstate '22023' then blocked:=sqlerrm='AAMIX_DECK_INITIAL_RESOURCE'; end;
 assert blocked,'09 new draft cannot omit Resource';
 r:=public.aamix_save_custom_deck(req,'','Con recurso','custom_restos','[{"codigo":"0100","cantidad":1}]',true,0);
 assert r->'saved_deck'->>'draft'='true' and public.aamix_save_custom_deck(req,'','Con recurso','custom_restos','[{"codigo":"0100","cantidad":1}]',true,0)->'saved_deck'=r->'saved_deck','10 valid draft and retry preserved';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa140.b'),'role','authenticated')::text,true);
 r:=public.aamix_inventory();
 assert r->'events'->0->'missions'->0->>'progress'='0' and r->>'restos'='0','11 another UUID has no login, progress, balance or claim';
end $$;
reset role;
-- Controlled completed receipts, including two that must not count (outside interval).
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,player_deck)
 select current_setting('qa140.a')::uuid,gen_random_uuid(),'kajido',stamp-interval '10 minutes',stamp,'victory',
  jsonb_build_object('id','kajido','cartas',d.cards)
 from aamix_private.base_decks d cross join (values('2026-10-20 23:59:59 America/Santiago'::timestamptz),
 ('2026-10-21 00:00:00 America/Santiago'::timestamptz),('2026-10-21 00:00:00 America/Santiago'::timestamptz),
 ('2026-10-21 00:00:00 America/Santiago'::timestamptz),('2026-10-27 00:00:00 America/Santiago'::timestamptz)) stamps(stamp) where d.id='kajido';
set local role authenticated;
do $$ declare r jsonb; before_prize jsonb; m text; begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa140.a'),'role','authenticated')::text,true);
 r:=public.aamix_inventory();
 assert r->'events'->0->'missions'->3->>'progress'='3' and r->'events'->0->'missions'->4->>'progress'='3','12 finish-window receipts count without historical/future leakage';
 before_prize:=r;
 foreach m in array array['play_one','win_one','play_three','win_three'] loop
  r:=public.aamix_claim_event_mission('bienvenida_2026',m);
  assert public.aamix_claim_event_mission('bienvenida_2026',m)->>'already_claimed'='true','13 event mission retries';
 end loop;
 assert (r->>'restos')::integer=(before_prize->>'restos')::integer+75 and (r->>'packs')::integer=(before_prize->>'packs')::integer+2
  and (r->>'normal_packs')::integer=(before_prize->>'normal_packs')::integer+1,'14 Welcome mission bundle amounts';
end $$;
reset role;
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-10-22 00:00:00 America/Santiago'::timestamptz $$;
set local role authenticated;
do $$ declare r jsonb; begin
 r:=public.aamix_inventory(); assert r->'events'->0->'missions'->0->>'progress'='0' and r->'events'->0->'missions'->1->>'claimed'='true','15 midnight resets only daily event login';
 perform public.aamix_events_sync(); r:=public.aamix_claim_event_mission('bienvenida_2026','login');
 assert r->>'already_claimed'='false','16 new day claim allowed';
end $$;
reset role;
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-10-26 23:59:59 America/Santiago'::timestamptz $$;
set local role authenticated;
do $$ begin assert jsonb_array_length(public.aamix_inventory()->'events')=1,'17 inclusive final day'; end $$;
reset role;
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-10-27 00:00:00 America/Santiago'::timestamptz $$;
set local role authenticated;
do $$ declare blocked boolean:=false; begin
 assert public.aamix_inventory()->'events'='[]'::jsonb,'18 expiry hides event';
 begin perform public.aamix_claim_event_mission('bienvenida_2026','login'); exception when sqlstate '22023' then blocked:=sqlerrm='AAMIX_EVENT_INACTIVE'; end;
 assert blocked,'19 expired claims rejected';
 assert public.aamix_redeem_code('BIENVENIDAA')->>'already_redeemed'='true','20 previously redeemed receipt survives code expiry';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa140.b'),'role','authenticated')::text,true);
 blocked:=false; begin perform public.aamix_redeem_code('BIENVENIDAA'); exception when sqlstate '22023' then blocked:=sqlerrm='AAMIX_CODE_INACTIVE'; end;
 assert blocked,'21 new redemption blocked after expiry';
end $$;
reset role;
-- Every remaining event, card reward and condition, using synthetic snapshots.
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-10-31 12:00:00 America/Santiago'::timestamptz $$;
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,player_deck)
 select current_setting('qa140.a')::uuid,gen_random_uuid(),'kajido','2026-10-31 11:00:00 America/Santiago','2026-10-31 11:59:00 America/Santiago','victory',
 jsonb_build_object('id','kajido','cartas',d.cards) from aamix_private.base_decks d cross join generate_series(1,5) where d.id='kajido';
set local role authenticated;
do $$ declare r jsonb; m text; begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa140.a'),'role','authenticated')::text,true);
 assert public.aamix_redeem_code('GATONEGRO')->'reward_cards'='[{"codigo":"01b","cantidad":1}]'::jsonb,'22 Halloween timed Bigotes';
 foreach m in array array['play_one','win_one','play_three','win_three','play_five','win_five'] loop r:=public.aamix_claim_event_mission('halloween_2026',m); end loop;
 assert r->'collection'->>'0117'='1' and r->'collection'->>'0122'='1' and r->'collection'->>'0128'='1','23 Halloween exact card rewards';
end $$;
reset role;
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-11-13 12:00:00 America/Santiago'::timestamptz $$;
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,player_deck)
 select current_setting('qa140.a')::uuid,gen_random_uuid(),'kajido','2026-11-13 11:00:00 America/Santiago','2026-11-13 11:59:00 America/Santiago','victory',
 jsonb_build_object('id','kajido','cartas',cards) from (values('[{"codigo":"0100","cantidad":40}]'::jsonb),('[{"codigo":"0100","cantidad":40}]'::jsonb),
 ('[{"codigo":"0104","cantidad":1},{"codigo":"0100","cantidad":39}]'::jsonb)) d(cards);
set local role authenticated;
do $$ declare r jsonb; blocked boolean:=false; begin
 r:=public.aamix_inventory();
 assert r->'events'->0->'missions'->1->>'progress'='1' and r->'events'->0->'missions'->2->>'progress'='1','24 Javieriv requires recorded card in starting deck';
 begin perform public.aamix_claim_event_mission('javieriv_2026','win_three_javieriv'); exception when sqlstate '22023' then blocked:=sqlerrm='AAMIX_MISSION_NOT_READY'; end;
 assert blocked,'25 wins without Javieriv do not qualify';
 perform public.aamix_claim_event_mission('javieriv_2026','play_one'); r:=public.aamix_claim_event_mission('javieriv_2026','win_one_javieriv');
 assert r->'collection'->>'0104'='2' and r->'event_reward'->>'normal_packs'='1','26 mixed card and pack reward';
end $$;
reset role;
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,player_deck)
 select current_setting('qa140.a')::uuid,gen_random_uuid(),'kajido','2026-11-13 11:00:00 America/Santiago','2026-11-13 11:59:00 America/Santiago','victory',
 '{"id":"kajido","cartas":[{"codigo":"0104","cantidad":1},{"codigo":"0100","cantidad":39}]}' from generate_series(1,2);
set local role authenticated;
do $$ declare r jsonb; begin
 r:=public.aamix_claim_event_mission('javieriv_2026','win_three_javieriv'); assert r->'collection'->>'0104'='3' and r->'event_reward'->>'packs'='1','27 third Javieriv reward';
end $$;
reset role;
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-11-26 12:00:00 America/Santiago'::timestamptz $$;
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,player_deck)
 select current_setting('qa140.a')::uuid,gen_random_uuid(),'maago','2026-11-26 11:00:00 America/Santiago','2026-11-26 11:59:00 America/Santiago','victory',
 '{"id":"maago","cartas":[{"codigo":"0105","cantidad":1},{"codigo":"0100","cantidad":39}]}' from generate_series(1,3);
set local role authenticated;
do $$ declare r jsonb; blocked boolean:=false; begin
 r:=public.aamix_inventory(); assert r->'events'->0->'missions'->1->>'progress'='0','28 birthday Kajido requires fixed Mazo Kajido, not pictured card';
 begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Portada bloqueada','custom_kajido','[{"codigo":"0100","cantidad":1}]',true,0); exception when sqlstate '22023' then blocked:=sqlerrm='AAMIX_DECK_COVER_LOCKED'; end;
 assert blocked,'29 unearned Kajido design locked';
 r:=public.aamix_redeem_code('CUMPLEKAJIDO'); assert r->>'reward_deck_id'='kajido' and jsonb_array_length(r->'reward_cards')>1,'30 birthday code full base deck';
end $$;
reset role;
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result,player_deck)
 select current_setting('qa140.a')::uuid,gen_random_uuid(),'kajido','2026-11-26 11:00:00 America/Santiago','2026-11-26 11:59:00 America/Santiago','victory',
 jsonb_build_object('id','kajido','cartas',d.cards) from aamix_private.base_decks d cross join generate_series(1,3) where d.id='kajido';
set local role authenticated;
do $$ declare r jsonb; owned integer; begin
 perform public.aamix_claim_event_mission('kajido_2026','play_one');
 r:=public.aamix_claim_event_mission('kajido_2026','win_one_kajido');
 assert r->'available_custom_covers' ? 'custom_kajido' and r->'event_reward'->>'restos'='50','31 Kajido permanent design plus 50';
 owned:=(r->'collection'->>'0105')::integer;
 r:=public.aamix_claim_event_mission('kajido_2026','win_three_kajido');
 assert (r->'collection'->>'0105')::integer=owned+1 and r->'event_reward'->>'restos'='100','32 Kajido card plus 100';
 r:=public.aamix_save_custom_deck(gen_random_uuid(),'','Portada ganada','custom_kajido','[{"codigo":"0100","cantidad":1}]',true,0);
 assert r->'saved_deck'->>'portada'='custom_kajido','33 earned design usable';
end $$;
reset role;
create or replace function aamix_private.event_clock() returns timestamptz language sql stable set search_path='' as $$ select '2026-11-28 00:00:00 America/Santiago'::timestamptz $$;
set local role authenticated;
do $$ declare r jsonb; begin r:=public.aamix_inventory();
 assert r->'events'='[]'::jsonb and r->'available_custom_covers' ? 'custom_kajido','34 event end preserves earned design';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa140.b'),'role','authenticated')::text,true);
 assert not (public.aamix_inventory()->'available_custom_covers' ? 'custom_kajido'),'35 design owner isolated';
end $$;
reset role;
select jsonb_build_object('sql_groups_passed',35,'synthetic_users_rolled_back',2,'event_missions',17,'real_emails_sent',0,'clock_override_rolled_back',true) as verification;
