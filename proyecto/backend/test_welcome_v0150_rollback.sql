begin;
set local plpgsql.check_asserts=on;
create temporary table qa015(label text,uid uuid default gen_random_uuid());
insert into qa015(label) values('a'),('b'),('legacy'),('overflow'),('unconfirmed');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
 select uid,uid::text||'@qa-v015.invalid',case when label='unconfirmed' then null else now() end,now(),now(),false from qa015;
select set_config('qa.a',(select uid::text from qa015 where label='a'),true);
select set_config('qa.b',(select uid::text from qa015 where label='b'),true);
select set_config('qa.legacy',(select uid::text from qa015 where label='legacy'),true);
select set_config('qa.overflow',(select uid::text from qa015 where label='overflow'),true);
select set_config('qa.unconfirmed',(select uid::text from qa015 where label='unconfirmed'),true);
insert into public.aamix_starter_gifts(user_id,deck_id) select uid,'kajido' from qa015 where label='legacy';
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
 select uid,d.id,d.name,d.cover,d.cards from qa015 cross join aamix_private.base_decks d where label='legacy' and d.id='kajido';
insert into public.aamix_collection(user_id,code,quantity)
 select uid,e->>'codigo',(e->>'cantidad')::integer from qa015 cross join aamix_private.base_decks d cross join lateral jsonb_array_elements(d.cards)e where label='legacy' and d.id='kajido';
insert into public.aamix_rewards_state(user_id,packs) select uid,case when label='overflow' then 2147483647 else 7 end from qa015 where label in('legacy','overflow');
set local role authenticated;
do $$
declare result jsonb; opening jsonb; request uuid:=gen_random_uuid(); caught boolean;
begin
  -- 01: owner read only, RLS enforced.
  assert (select relrowsecurity from pg_class where oid='public.aamix_welcome_packs'::regclass)
    and not has_table_privilege('authenticated','public.aamix_welcome_packs','INSERT'), '01 RLS and no writes';
  -- 02: public invoker, no anonymous execution.
  assert not has_function_privilege('anon','public.aamix_claim_welcome_pack()','EXECUTE') and
    not(select prosecdef from pg_proc where oid='public.aamix_claim_welcome_pack()'::regprocedure), '02 invoker ACL';
  perform set_config('request.jwt.claims','{}',true);
  caught:=false; begin perform public.aamix_claim_welcome_pack(); exception when sqlstate '28000' then caught:=true; end;
  assert caught, '03 unauthenticated rejected';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.unconfirmed'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_claim_welcome_pack(); exception when sqlstate '28000' then caught:=true; end;
  assert caught, '04 unconfirmed rejected';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.a'),'role','authenticated')::text,true);
  result:=public.aamix_inventory();
  assert result->'gift'='null'::jsonb and result->>'packs'='0' and not(result->'welcome_pack'->>'claimed')::boolean,'05 fresh inventory';
  caught:=false; begin perform public.aamix_claim_starter('kajido'); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_START_CHALLENGE'; end;
  assert caught, '06 starter requires challenge';
  result:=public.aamix_claim_welcome_pack();
  assert result->>'packs'='1' and result->>'welcome_awarded'='true' and result->'decks'='[]'::jsonb and result->'collection'='{}'::jsonb,'07 welcome pack only';
  for i in 1..10 loop result:=public.aamix_claim_welcome_pack(); end loop;
  assert result->>'packs'='1' and result->>'welcome_awarded'='false' and (select count(*) from public.aamix_welcome_packs)=1,'08 ten retries once';
  caught:=false; begin perform public.aamix_claim_starter('kajido'); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_START_CHALLENGE'; end;
  assert caught, '09 welcome alone does not grant deck';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.b'),'role','authenticated')::text,true);
  assert (select count(*) from public.aamix_welcome_packs)=0 and public.aamix_inventory()->>'packs'='0','10 account isolation';
  result:=public.aamix_enter_challenge();
  assert result->>'packs'='1' and result->'decks'='[]'::jsonb and result->'welcome_pack'->>'challenge_entered'='true','11 entry grants welcome if needed';
  result:=public.aamix_claim_starter('papito');
  assert result->'gift'->>'deck_id'='papito' and jsonb_array_length(result->'decks')=1 and (select sum(quantity) from public.aamix_collection)=40,'12 starter forty';
  result:=public.aamix_claim_starter('flaan');
  assert result->'gift'->>'deck_id'='papito' and result->>'already_claimed'='true' and (select sum(quantity) from public.aamix_collection)=40,'13 starter retry no duplicates';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.a'),'role','authenticated')::text,true);
  result:=public.aamix_open_pack(request); opening:=result->'pending_opening';
  assert result->>'packs'='0' and jsonb_array_length(opening->'cards')=5 and (select sum(quantity) from public.aamix_collection)=5,'14 welcome can be opened';
  result:=public.aamix_open_pack(request);
  assert result->'pending_opening'=opening and (select sum(quantity) from public.aamix_collection)=5,'15 pack retry same five';
  perform public.aamix_enter_challenge(); result:=public.aamix_claim_starter('kajido');
  assert result->>'packs'='0' and (select sum(quantity) from public.aamix_collection)=45,'16 later starter preserves five cards';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.legacy'),'role','authenticated')::text,true);
  result:=public.aamix_claim_welcome_pack(); perform public.aamix_enter_challenge();
  assert result->>'packs'='7' and result->>'welcome_awarded'='false' and result->'gift'->>'deck_id'='kajido' and (select count(*) from public.aamix_welcome_packs)=0,'17 legacy no new award';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.overflow'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_claim_welcome_pack(); exception when numeric_value_out_of_range then caught:=true; end;
  assert caught and (select count(*) from public.aamix_welcome_packs)=0 and public.aamix_inventory()->>'packs'='2147483647','18 overflow fully rolled back';
  result:=public.aamix_inventory();
  assert jsonb_array_length(result->'missions')=4 and jsonb_array_length(result->'challenges')=5 and result->'mission'->>'id'='play_one','19 old inventory contract preserved';
  caught:=false; begin update public.aamix_welcome_packs set challenge_entered_at=now(); exception when insufficient_privilege then caught:=true; end;
  assert caught,'20 direct update denied';
end $$;
rollback;
select jsonb_build_object('checks',20,'failures',0,'all_fixtures_rolled_back',true,'real_rewards_claimed',0) as welcome_v015_result;
