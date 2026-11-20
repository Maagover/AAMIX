begin;
set local plpgsql.check_asserts=on;
create temporary table qa111_users(uid uuid default gen_random_uuid());
insert into qa111_users default values;
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
 select uid,uid::text||'@qa-v111.invalid',now(),now(),now(),false from qa111_users;
select set_config('qa111.uid',(select uid::text from qa111_users),true);
insert into public.aamix_rewards_state(user_id)select uid from qa111_users;
insert into public.aamix_collection(user_id,code,quantity)select uid,'0100',80 from qa111_users;
insert into public.aamix_collection(user_id,code,quantity)select uid,'0104',3 from qa111_users;
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
 select uid,'papito','QA','custom_restos','[{"codigo":"0100","cantidad":37},{"codigo":"0104","cantidad":3}]' from qa111_users;
insert into public.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent,player_deck,result,finished_at)
 select uid,gen_random_uuid(),'papito',stage,jsonb_build_object('id',d->>'deck_id','cartas','[]'::jsonb),
 jsonb_build_object('id','papito','cartas','[{"codigo":"0100","cantidad":37},{"codigo":"0104","cantidad":3}]'::jsonb),'victory',now()
 from qa111_users cross join generate_series(1,11) s(stage) join lateral(select value d from jsonb_array_elements(aamix_private.challenge_definitions()) where (value->>'stage')::integer=stage) t on true;
insert into public.aamix_challenge_completions(user_id,stage,winning_match_id,reward_packs)
 select user_id,challenge_stage,match_id,case when challenge_stage<=3 then 1 when challenge_stage=4 then 2 else 3 end from public.aamix_match_receipts where user_id=(select uid from qa111_users);
set local role authenticated;
do $$
declare r jsonb;m jsonb;mid uuid;before integer;after integer;caught boolean;uid uuid:=current_setting('qa111.uid')::uuid;
begin
 assert not has_function_privilege('anon','public.aamix_finish_challenge_v111(uuid,text,jsonb)','EXECUTE'),'anon denied';
 assert not has_table_privilege('authenticated','aamix_private.challenge_claims_v111','INSERT'),'no direct claims';
 assert not has_table_privilege('authenticated','aamix_private.challenge_metrics_v111','SELECT'),'private metrics';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated')::text,true);
 assert jsonb_array_length(aamix_private.challenge_missions_v111(1))=1,'level 1 mission count';
 assert jsonb_array_length(aamix_private.challenge_missions_v111(4))=2,'level 4 mission count';
 assert jsonb_array_length(aamix_private.challenge_missions_v111(6))=3,'level 6 mission count';
 assert jsonb_array_length(aamix_private.challenge_missions_v111(9))=3,'level 9 excludes no losses';
 assert jsonb_array_length(aamix_private.challenge_missions_v111(10))=3,'level 10 excludes no losses';
 assert jsonb_array_length(aamix_private.challenge_missions_v111(11))=4,'only level 11 includes no losses';
 select value into m from jsonb_array_elements(aamix_private.challenge_missions_v111(11))where value->>'id'='no_singular';
 assert m->>'can_claim'='true','frozen nonsingular deck qualifies';
 r:=public.aamix_inventory();before:=(r->>'packs')::integer;
 r:=public.aamix_claim_challenge_mission_v111(11,'no_singular');
 assert (r->>'packs')::integer=before+1,'claim grants one TC';
 r:=public.aamix_claim_challenge_mission_v111(11,'no_singular');
 assert (r->>'packs')::integer=before+1,'claim retry is idempotent';
 caught:=false;begin perform public.aamix_claim_challenge_mission_v111(9,'no_losses');exception when sqlstate '22023' then caught:=true;end;
 assert caught,'unknown mission rejected';
 for i in 1..4 loop
  r:=public.aamix_begin_challenge_match(gen_random_uuid(),'papito',11);mid:=(r->>'match_id')::uuid;
  r:=public.aamix_finish_challenge_v111(mid,'victory','{"deck_remaining":21,"allies_lost":0}');
 end loop;
 select value into m from jsonb_array_elements(aamix_private.challenge_missions_v111(11))where value->>'id'='win_five';
 assert m->>'progress'='5' and m->>'can_claim'='true','five wins accumulated on one level';
 before:=(r->>'packs')::integer;
 r:=public.aamix_claim_challenge_mission_v111(11,'win_five');assert (r->>'packs')::integer=before+2,'five wins grants two TC';
 r:=public.aamix_claim_challenge_mission_v111(11,'keep_twenty');assert (r->>'packs')::integer=before+3,'21 cards qualifies';
 r:=public.aamix_claim_challenge_mission_v111(11,'no_losses');assert (r->>'packs')::integer=before+6,'no ally losses grants three TC';
 r:=public.aamix_finish_challenge_v111(mid,'victory','{"deck_remaining":0,"allies_lost":99}');
 assert (r->>'packs')::integer=before+6,'finish retry does not duplicate reward';
 r:=public.aamix_begin_challenge_match(gen_random_uuid(),'papito',6);mid:=(r->>'match_id')::uuid;
 r:=public.aamix_finish_challenge_v111(mid,'victory','{"deck_remaining":20,"allies_lost":1}');
 select value into m from jsonb_array_elements(aamix_private.challenge_missions_v111(6))where value->>'id'='keep_twenty';
 assert m->>'progress'='0','exactly 20 does not qualify';
 r:=public.aamix_begin_challenge_match(gen_random_uuid(),'papito',6);mid:=(r->>'match_id')::uuid;
 r:=public.aamix_finish_challenge_v111(mid,'defeat','{"deck_remaining":30,"allies_lost":0}');
 select value into m from jsonb_array_elements(aamix_private.challenge_missions_v111(6))where value->>'id'='keep_twenty';
 assert m->>'progress'='0','defeat does not qualify';
 caught:=false;begin perform public.aamix_finish_challenge_v111(gen_random_uuid(),'victory','{}');exception when sqlstate '22023' then caught:=true;end;
 assert caught,'foreign unknown receipt rejected';
 raise notice 'QA v111: reward amounts, 11 levels, thresholds, idempotency and access passed. All writes rollback.';
end$$;
rollback;

