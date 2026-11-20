begin;
set local plpgsql.check_asserts=on;
create temp table qa180_people(slot integer primary key,id uuid default gen_random_uuid());
insert into qa180_people(slot) values(1),(2),(3);
insert into auth.users(id,aud,role,email,email_confirmed_at,raw_user_meta_data,raw_app_meta_data,created_at,updated_at)
select id,'authenticated','authenticated','qa-final-v180-'||id||'@example.invalid',now(),'{"display_name":"Prueba final"}','{"provider":"email","providers":["email"]}',now(),now() from qa180_people;
insert into public.aamix_rewards_state(user_id) select id from qa180_people;
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
select p.id,d.id,d.name,d.cover,d.cards from qa180_people p cross join aamix_private.base_decks d where d.id='kajido';
insert into public.aamix_collection(user_id,code,quantity)
select p.id,c->>'codigo',(c->>'cantidad')::integer from qa180_people p cross join aamix_private.base_decks d cross join jsonb_array_elements(d.cards)c where d.id='kajido';
update public.aamix_collection set quantity=40 where code='0100' and user_id in(select id from qa180_people);
-- Existing earned claim must remain after moving the event start date.
insert into aamix_private.event_claims(user_id,event_id,mission_id,period_key,reward)
select id,'bienvenida_2026','play_one','event','{"restos":25}' from qa180_people where slot=3;
-- APPLY_V180_HERE
create temp table qa180_results(name text primary key,ok boolean not null);
create function pg_temp.qa(ok boolean,label text) returns void language plpgsql security definer as $$begin
 if ok is distinct from true then raise exception 'QA FAILED: %',label;end if;insert into qa180_results values(label,true);end $$;
create function pg_temp.denied(command text,expected text,label text) returns void language plpgsql as $$begin
 begin execute command;exception when others then if sqlerrm=expected then perform pg_temp.qa(true,label);return;end if;raise exception 'Unexpected error %: %',label,sqlerrm;end;
 raise exception 'Unexpectedly allowed: %',label;end $$;
select pg_temp.qa((select start_day='2026-10-23' and end_day='2026-10-26' from aamix_private.event_definitions where id='bienvenida_2026'),'Welcome dates moved without resetting event identity');
select pg_temp.qa((select count(*)=1 from aamix_private.event_claims where user_id=(select id from qa180_people where slot=3)),'Previously claimed event reward retained');
grant select on qa180_people to authenticated;
set local role authenticated;
do $$declare a uuid:=(select id from qa180_people where slot=1);b uuid:=(select id from qa180_people where slot=2);
 j jsonb;saved jsonb;deck text;mid uuid;req uuid:=gen_random_uuid();room uuid;v integer;cards jsonb;total integer:=0;
begin
 perform pg_temp.qa(not has_function_privilege('anon','public.aamix_delete_custom_deck(text,integer)','execute'),'Anonymous delete RPC is denied');
 perform pg_temp.qa(not has_table_privilege('authenticated','aamix_private.deleted_custom_decks_v180','select'),'Delete tombstones stay private');
 perform pg_temp.qa(not has_column_privilege('authenticated','public.aamix_match_receipts','challenge_repeat_restos','update'),'Clients cannot forge bonus amounts');
 perform set_config('request.jwt.claim.sub',a::text,true);
 cards:=public.aamix_inventory()->'collection';
 j:=public.aamix_save_custom_deck(req,'','Borrador QA','custom_restos','[{"codigo":"0100","cantidad":40}]',false,0);saved:=j->'last_saved_deck';deck:=saved->>'id';
 perform pg_temp.denied('select public.aamix_delete_custom_deck(''kajido'',1)','AAMIX_DECK_IMMUTABLE','Gift/base deck cannot be deleted');
 perform pg_temp.denied(format('select public.aamix_delete_custom_deck(%L,2)',deck),'AAMIX_DECK_REVISION_CONFLICT','Stale revision cannot delete a newer deck');
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform pg_temp.denied(format('select public.aamix_delete_custom_deck(%L,1)',deck),'AAMIX_UNOWNED_DECK','Other UUID cannot delete custom deck');
 perform set_config('request.jwt.claim.sub',a::text,true);
 j:=public.aamix_mp_create_room(gen_random_uuid(),deck);room:=(j->>'room_id')::uuid;
 if room is null then room:=(j->'room'->>'id')::uuid;end if;
 perform pg_temp.denied(format('select public.aamix_delete_custom_deck(%L,1)',deck),'AAMIX_DECK_IN_ROOM','Deck selected in active room cannot be deleted');
 perform public.aamix_mp_leave(room);
 j:=public.aamix_begin_match(gen_random_uuid(),deck);mid:=(j->>'match_id')::uuid;
 j:=public.aamix_delete_custom_deck(deck,1);
 perform pg_temp.qa(j->>'deleted_deck_id'=deck and not (j->>'already_deleted')::boolean,'Owner deletes only the saved custom deck');
 perform pg_temp.qa(j->'collection'=cards,'Deleting deck does not consume or remove any cards');
 perform pg_temp.qa(not exists(select 1 from jsonb_array_elements(j->'decks')d where d->>'id'=deck),'Deleted deck absent from inventory');
 j:=public.aamix_delete_custom_deck(deck,1);perform pg_temp.qa((j->>'already_deleted')::boolean and j->'collection'=cards,'Delete retry is idempotent');
 j:=public.aamix_save_custom_deck(req,'','Borrador QA','custom_restos','[{"codigo":"0100","cantidad":40}]',false,0);
 perform pg_temp.qa(not exists(select 1 from jsonb_array_elements(j->'decks')d where d->>'id'=deck),'Old save request replay cannot resurrect deleted deck');
 j:=public.aamix_finish_match(mid,'victory');perform pg_temp.qa(j->>'match_result'='victory' and (j->>'challenge_repeat_restos')::int=0,'Existing match snapshot survives deck deletion with no challenge bonus');
 for v in 1..5 loop
  j:=public.aamix_begin_challenge_match(gen_random_uuid(),'kajido',v);mid:=(j->>'match_id')::uuid;j:=public.aamix_finish_match(mid,'victory');
  perform pg_temp.qa((j->>'challenge_repeat_restos')::int=0,'Initial challenge completion stage '||v||' grants no repeat bonus');
 end loop;
 perform pg_temp.qa((j->>'packs')::int=8 and (j->>'restos')::int=0,'Original eight TC packs preserved; first clear does not add repeat Restos');
 for v in 1..5 loop
  j:=public.aamix_begin_challenge_match(gen_random_uuid(),'kajido',v);mid:=(j->>'match_id')::uuid;j:=public.aamix_finish_match(mid,'victory');total:=total+5;
  perform pg_temp.qa((j->>'challenge_repeat_restos')::int=5 and (j->>'restos')::int=total,'Completed challenge repeat stage '||v||' grants exactly five Restos');
  j:=public.aamix_finish_match(mid,'victory');perform pg_temp.qa((j->>'restos')::int=total and (j->>'challenge_repeat_restos')::int=5,'Receipt replay stage '||v||' reports award without crediting it twice');
 end loop;
 j:=public.aamix_begin_challenge_match(gen_random_uuid(),'kajido',1);mid:=(j->>'match_id')::uuid;j:=public.aamix_finish_match(mid,'defeat');
 perform pg_temp.qa((j->>'challenge_repeat_restos')::int=0 and (j->>'restos')::int=25,'Defeat never gives repeat Restos');
 j:=public.aamix_begin_match(gen_random_uuid(),'kajido');mid:=(j->>'match_id')::uuid;j:=public.aamix_finish_match(mid,'victory');
 perform pg_temp.qa((j->>'challenge_repeat_restos')::int=0 and (j->>'restos')::int=25,'Ordinary victory never gives challenge repeat Restos');
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform pg_temp.denied(format('select public.aamix_finish_match(%L,''victory'')',mid),'Unknown match receipt','Other UUID cannot finish or receive someone else reward');
 j:=public.aamix_begin_challenge_match(gen_random_uuid(),'kajido',1);mid:=(j->>'match_id')::uuid;j:=public.aamix_finish_match(mid,'victory');
 perform pg_temp.qa((j->>'challenge_repeat_restos')::int=0 and (j->>'restos')::int=0,'Completion eligibility is isolated by player UUID');
end $$;
reset role;
select jsonb_build_object('checks',count(*),'passed',bool_and(ok),'synthetic_users_rolled_back',3,'results',jsonb_agg(name order by name)) as online_final_v180_sql from qa180_results;
rollback;
