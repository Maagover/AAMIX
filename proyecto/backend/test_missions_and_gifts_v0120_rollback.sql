-- Run AFTER aamix_missions_and_gifts_v0120.sql. Random synthetic users only.
-- Every user, receipt, claim and reward rolls back; no real mailbox or account used.
begin;
set local plpgsql.check_asserts=on;
set local timezone='Pacific/Honolulu'; -- Client/session timezone must not alter Chile days.
create temporary table aamix_v012_users(label text primary key,uid uuid not null default gen_random_uuid());
insert into aamix_v012_users(label) values('a'),('legacy'),('midnight'),('empty'),('overflow'),('unconfirmed'),('anonymous');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@aamix-v012-qa.invalid',case when label='unconfirmed' then null else now() end,now(),now(),label='anonymous' from pg_temp.aamix_v012_users;
select set_config('aamix.v012_a',(select uid::text from pg_temp.aamix_v012_users where label='a'),true);
select set_config('aamix.v012_legacy',(select uid::text from pg_temp.aamix_v012_users where label='legacy'),true);
select set_config('aamix.v012_midnight',(select uid::text from pg_temp.aamix_v012_users where label='midnight'),true);
select set_config('aamix.v012_empty',(select uid::text from pg_temp.aamix_v012_users where label='empty'),true);
select set_config('aamix.v012_overflow',(select uid::text from pg_temp.aamix_v012_users where label='overflow'),true);
select set_config('aamix.v012_unconfirmed',(select uid::text from pg_temp.aamix_v012_users where label='unconfirmed'),true);
select set_config('aamix.v012_anonymous',(select uid::text from pg_temp.aamix_v012_users where label='anonymous'),true);
-- Realistic historic owned Maagover decks/cards, before this release's claims.
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select u.uid,d.id,d.name,d.cover,d.cards from pg_temp.aamix_v012_users u cross join aamix_private.base_decks d
  where u.label in('a','legacy','midnight','empty','overflow') and d.id='maago';
insert into public.aamix_collection(user_id,code,quantity)
  select u.uid,e->>'codigo',(e->>'cantidad')::integer
  from pg_temp.aamix_v012_users u cross join aamix_private.base_decks d cross join lateral jsonb_array_elements(d.cards) e
  where u.label in('a','legacy','midnight','empty') and d.id='maago';
insert into public.aamix_collection(user_id,code,quantity)
  select uid,'0100',2147483647 from pg_temp.aamix_v012_users where label='overflow';
insert into public.aamix_rewards_state(user_id,packs)
  select uid,case when label='overflow' then 2147483647 when label='legacy' then 1 else 0 end
  from pg_temp.aamix_v012_users where label in('a','legacy','midnight','empty','overflow');
-- A has8 older games and1 defeat today: lifetime9; no win today.
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select u.uid,gen_random_uuid(),'maago',now()-(s.n+2)*interval '1 day',now()-(s.n+1)*interval '1 day','victory'
  from pg_temp.aamix_v012_users u cross join generate_series(1,8) s(n) where u.label='a';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',now()-interval '5 minutes',now(),'defeat' from pg_temp.aamix_v012_users where label='a';
-- Legacy account has10 completed games, one victory today and PLAY1 already paid.
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select u.uid,gen_random_uuid(),'maago',now()-(s.n+2)*interval '1 day',now()-(s.n+1)*interval '1 day','defeat'
  from pg_temp.aamix_v012_users u cross join generate_series(1,9) s(n) where u.label='legacy';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',now()-interval '5 minutes',now(),'victory' from pg_temp.aamix_v012_users where label='legacy';
insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id,claimed_at)
  select u.uid,(now() at time zone 'America/Santiago')::date,r.match_id,now()
  from pg_temp.aamix_v012_users u join public.aamix_match_receipts r on r.user_id=u.uid
  where u.label='legacy' and r.result='victory';
-- Every pre-existing gift-code redemption remains an already-used gate.
insert into public.aamix_code_redemptions(user_id,gift_code)
  select u.uid,c.gift_code from pg_temp.aamix_v012_users u cross join aamix_private.gift_code_rewards c
  where u.label='legacy' and c.gift_code not in('AAMIXTC','M4Z0G1R4');
-- Boundary test: victory one microsecond before midnight; defeat exactly at midnight.
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago')-interval '5 minutes',
         ((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago')-interval '1 microsecond','victory'
  from pg_temp.aamix_v012_users where label='midnight';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago')-interval '3 minutes',
         ((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago'),'defeat'
  from pg_temp.aamix_v012_users where label='midnight';
insert into public.aamix_mission_claims(user_id,mission_id,period_key)
  select uid,'win_one',((now() at time zone 'America/Santiago')::date-1)::text from pg_temp.aamix_v012_users where label='midnight';
-- Overflow account is eligible for all missions, but all awards must abort atomically.
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select u.uid,gen_random_uuid(),'maago',now()-interval '5 minutes',now(),'victory'
  from pg_temp.aamix_v012_users u cross join generate_series(1,10) s(n) where u.label='overflow';

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v012_a'),'role','authenticated')::text,true);
do $$
declare r jsonb; baseline jsonb; mid uuid; request uuid:=gen_random_uuid(); i integer; opening jsonb;
begin
  r:=public.aamix_inventory();
  assert jsonb_array_length(r->'missions')=3;
  assert r->'mission'=(r->'missions'->0)-'scope','Legacy mission shape differs';
  assert r->'mission'->>'id'='play_one' and (r->'mission'->>'progress')::integer=1;
  assert (r->'missions'->1->>'progress')::integer=0 and (r->'missions'->2->>'progress')::integer=9,'Historic receipt progress not counted';
  assert r->'missions'->2->>'scope'='lifetime' and r->'missions'->2->'day'='null'::jsonb;
  begin perform public.aamix_claim_mission('win_one'); raise exception 'Defeat counted as daily victory'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_claim_mission('play_ten'); raise exception 'Nine games counted as ten'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_claim_mission('forged'); raise exception 'Unknown mission accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_claim_mission(null); raise exception 'NULL mission accepted'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_claim_daily_mission();
  assert (r->>'packs')::integer=1 and r->>'already_claimed'='false' and r->>'mission_id'='play_one';
  assert r->'mission'->>'claimed'='true' and r->'missions'->1->>'claimed'='false' and r->'missions'->2->>'claimed'='false';
  for i in 1..20 loop
    r:=public.aamix_claim_mission('play_one');
    assert r->>'already_claimed'='true' and (r->>'packs')::integer=1,'Generic and legacy claims paid twice';
  end loop;
  r:=public.aamix_begin_match(request,'maago'); mid:=(r->>'match_id')::uuid;
  assert (r->'missions'->2->>'progress')::integer=9,'Unfinished game counted';
  for i in 1..20 loop assert (public.aamix_begin_match(request,'maago')->>'match_id')::uuid=mid; end loop;
  r:=public.aamix_finish_match(mid,'victory');
  assert (r->'missions'->1->>'progress')::integer=1 and (r->'missions'->2->>'progress')::integer=10;
  assert (r->>'packs')::integer=1,'Completion granted unclaimed rewards';
  for i in 1..20 loop
    r:=public.aamix_finish_match(mid,'victory');
    assert (r->'missions'->2->>'progress')::integer=10 and (select count(*) from public.aamix_match_receipts)=10,'Finish retry counted twice';
  end loop;
  begin perform public.aamix_finish_match(mid,'defeat'); raise exception 'Finished result changed'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_claim_mission('win_one');
  assert r->>'already_claimed'='false' and (r->>'packs')::integer=2 and (r->>'reward_packs')::integer=1;
  assert r->'missions'->2->>'claimed'='false','Daily claim changed lifetime claim';
  r:=public.aamix_claim_mission('play_ten');
  assert r->>'already_claimed'='false' and (r->>'packs')::integer=7 and (r->>'reward_packs')::integer=5;
  for i in 1..20 loop
    r:=public.aamix_claim_mission('play_ten');
    assert r->>'already_claimed'='true' and (r->>'packs')::integer=7;
    r:=public.aamix_claim_mission('win_one');
    assert r->>'already_claimed'='true' and (r->>'packs')::integer=7;
    r:=public.aamix_claim_daily_mission();
    assert r->>'already_claimed'='true' and (r->>'packs')::integer=7;
  end loop;
  r:=public.aamix_begin_match(gen_random_uuid(),'maago');
  r:=public.aamix_finish_match((r->>'match_id')::uuid,'defeat');
  assert (select count(*) from public.aamix_match_receipts)=11;
  assert (r->'missions'->2->>'progress')::integer=10 and r->'missions'->2->>'claimed'='true','Lifetime progress reset after claiming';
  r:=public.aamix_claim_mission('play_ten');
  assert r->>'already_claimed'='true' and (r->>'packs')::integer=7,'Extra games granted another lifetime reward';
  baseline:=public.aamix_inventory();
  r:=public.aamix_redeem_code(' aamixtc ');
  assert r->>'already_redeemed'='false' and r->>'redeemed_code'='AAMIXTC';
  assert (r->>'reward_packs')::integer=1 and r->'reward_cards'='[]'::jsonb and r->'reward_deck_id'='null'::jsonb;
  assert (r->>'packs')::integer=8 and r->'collection'=baseline->'collection' and r->'decks'=baseline->'decks';
  for i in 1..20 loop
    r:=public.aamix_redeem_code('AAMIXTC');
    assert r->>'already_redeemed'='true' and (r->>'packs')::integer=8;
  end loop;
  begin perform public.aamix_claim_starter('girabl'); raise exception 'Girabl accepted as starter'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_redeem_code('m4z0g1r4');
  assert r->>'already_redeemed'='false' and r->>'reward_deck_id'='girabl' and r->>'reward_name'='Mazo Girabl';
  assert (r->>'reward_packs')::integer=0 and (r->>'packs')::integer=8;
  assert (select sum((e->>'cantidad')::integer) from jsonb_array_elements(r->'reward_cards') e)=40;
  assert (select (e->>'cantidad')::integer from jsonb_array_elements(r->'reward_cards') e where e->>'codigo'='0100')=12;
  assert (r->'collection'->>'0100')::integer=27 and (select sum(value::integer) from jsonb_each_text(r->'collection'))=80;
  assert jsonb_array_length(r->'decks')=2 and r->'gift'='null'::jsonb;
  assert exists(select 1 from jsonb_array_elements(r->'decks') d where d->>'id'='girabl' and d->>'portada'='0127' and d->'cartas'=r->'reward_cards');
  baseline:=r-'already_redeemed';
  for i in 1..20 loop
    r:=public.aamix_redeem_code('M4Z0G1R4');
    assert r->>'already_redeemed'='true' and r-'already_redeemed'=baseline,'Girabl retry duplicated award';
  end loop;
  -- A legitimate promotional card in the obtained Girabl deck remains owned/locked.
  assert (r->'collection'->>'01a')::integer=3;
  begin perform public.aamix_set_avatar('01a'); raise exception 'Girabl promo unlocked avatar'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_redeem_code('P3RI');
  assert (r->'collection'->>'01a')::integer=6 and (r->>'reward_packs')::integer=0 and (r->>'packs')::integer=8;
  r:=public.aamix_open_pack(gen_random_uuid()); opening:=r->'opening';
  assert (r->>'packs')::integer=7 and jsonb_array_length(opening->'cards')=5;
  r:=public.aamix_acknowledge_opening((opening->>'opening_id')::uuid);
  assert r->'pending_opening'='null'::jsonb;
  begin update public.aamix_mission_claims set period_key='lifetime'; raise exception 'Forged claim write'; exception when insufficient_privilege then null; end;
  begin delete from public.aamix_mission_claims; raise exception 'Claim reset'; exception when insufficient_privilege then null; end;
  begin update public.aamix_rewards_state set packs=999; raise exception 'Forged pack amount'; exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v012_legacy'),'role','authenticated')::text,true);
do $$
declare r jsonb; baseline jsonb; c text;
begin
  r:=public.aamix_inventory();
  assert r->'mission'->>'claimed'='true' and (r->>'packs')::integer=1;
  assert (r->'missions'->1->>'progress')::integer=1 and (r->'missions'->2->>'progress')::integer=10,'Retroactive historic games ignored';
  assert r->'missions'->1->>'claimed'='false' and r->'missions'->2->>'claimed'='false','Other UUID claims leaked';
  baseline:=r;
  foreach c in array array['M4Z0M44G0','P3RI','B1G0T3S','SI2TYA','CHANCHULINES','TORNEOAAMIX1'] loop
    r:=public.aamix_redeem_code(c);
    assert r->>'already_redeemed'='true' and (r->>'reward_packs')::integer=0;
    assert r-'already_redeemed'-'redeemed_code'-'reward_name'-'reward_deck_id'-'reward_cards'-'reward_packs'=baseline,'Old redemption repeated after extension';
  end loop;
  r:=public.aamix_claim_mission('play_one');
  assert r->>'already_claimed'='true' and (r->>'packs')::integer=1,'Old PLAY1 reward paid again';
  r:=public.aamix_claim_daily_mission();
  assert r->>'already_claimed'='true' and (r->>'packs')::integer=1;
  r:=public.aamix_claim_mission('win_one'); assert (r->>'packs')::integer=2;
  r:=public.aamix_claim_mission('play_ten'); assert (r->>'packs')::integer=7;
  r:=public.aamix_redeem_code('AAMIXTC');
  assert r->>'already_redeemed'='false' and (r->>'packs')::integer=8,'Pack code incorrectly global';
  assert (select count(*) from public.aamix_mission_claims)=2,'RLS claims leak';
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v012_midnight'),'role','authenticated')::text,true);
do $$
declare r jsonb; yesterday_id uuid;
begin
  r:=public.aamix_inventory();
  assert r->'mission'->>'day'=((now() at time zone 'America/Santiago')::date)::text;
  assert (r->'mission'->>'progress')::integer=1 and (r->'missions'->1->>'progress')::integer=0 and (r->'missions'->2->>'progress')::integer=2;
  assert r->'missions'->1->>'claimed'='false','Yesterday claim carried into new day';
  select match_id into yesterday_id from public.aamix_match_receipts where result='victory';
  r:=public.aamix_finish_match(yesterday_id,'victory');
  assert (r->'missions'->1->>'progress')::integer=0 and (r->'missions'->2->>'progress')::integer=2,'Yesterday receipt replay counted today';
  begin perform public.aamix_claim_mission('win_one'); raise exception 'Yesterday win qualified today'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_claim_daily_mission();
  assert (r->>'packs')::integer=1 and r->>'already_claimed'='false','00:00 defeat did not qualify current day';
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v012_empty'),'role','authenticated')::text,true);
do $$
declare c text; r jsonb;
begin
  r:=public.aamix_inventory();
  assert (r->'missions'->0->>'progress')::integer=0 and (r->'missions'->1->>'progress')::integer=0 and (r->'missions'->2->>'progress')::integer=0;
  assert (select count(*) from public.aamix_mission_claims)=0;
  foreach c in array array['play_one','win_one','play_ten'] loop
    begin perform public.aamix_claim_mission(c); raise exception 'Unfinished mission claimed'; exception when invalid_parameter_value then null; end;
  end loop;
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v012_overflow'),'role','authenticated')::text,true);
do $$
declare c text; baseline jsonb;
begin
  baseline:=public.aamix_inventory();
  foreach c in array array['play_one','win_one','play_ten'] loop
    begin perform public.aamix_claim_mission(c); raise exception 'Expected mission overflow'; exception when numeric_value_out_of_range then null; end;
    assert public.aamix_inventory()=baseline,'Mission failure partially committed';
    assert (select count(*) from public.aamix_mission_claims)=0 and (select count(*) from public.aamix_daily_missions)=0;
  end loop;
  begin perform public.aamix_redeem_code('AAMIXTC'); raise exception 'Expected pack overflow'; exception when numeric_value_out_of_range then null; end;
  assert public.aamix_inventory()=baseline and (select count(*) from public.aamix_code_redemptions)=0;
  begin perform public.aamix_redeem_code('M4Z0G1R4'); raise exception 'Expected Girabl collection overflow'; exception when numeric_value_out_of_range then null; end;
  assert public.aamix_inventory()=baseline and (select count(*) from public.aamix_code_redemptions)=0;
end $$;

do $$
declare label text; c text;
begin
  foreach label in array array['unconfirmed','anonymous'] loop
    perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v012_'||label),'role','authenticated')::text,true);
    foreach c in array array['play_one','win_one','play_ten'] loop
      begin perform public.aamix_claim_mission(c); raise exception 'Unverified mission'; exception when invalid_authorization_specification then null; end;
    end loop;
    foreach c in array array['AAMIXTC','M4Z0G1R4'] loop
      begin perform public.aamix_redeem_code(c); raise exception 'Unverified gift'; exception when invalid_authorization_specification then null; end;
    end loop;
  end loop;
  perform set_config('request.jwt.claims','{}',true);
  begin perform public.aamix_claim_mission('play_ten'); raise exception 'Missing UUID accepted'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v012_a'),'role','authenticated')::text,true);
do $$
declare i integer; slot integer; cards jsonb; expected jsonb;
begin
  expected:='[{"codigo":"0127","cantidad":3},{"codigo":"01a","cantidad":3},{"codigo":"0108","cantidad":3},{"codigo":"0104","cantidad":2},{"codigo":"01b","cantidad":2},{"codigo":"0113","cantidad":2},{"codigo":"0112","cantidad":2},{"codigo":"0107","cantidad":1},{"codigo":"0111","cantidad":1},{"codigo":"01c","cantidad":1},{"codigo":"0116","cantidad":2},{"codigo":"0120","cantidad":3},{"codigo":"0124","cantidad":3},{"codigo":"0100","cantidad":12}]'::jsonb;
  assert (select d.cards from aamix_private.base_decks d where d.id='girabl')=expected;
  assert (select d.cards from public.aamix_owned_decks d where d.user_id=auth.uid() and d.deck_id='girabl')=expected;
  assert (select count(*) from aamix_private.gift_code_rewards)=8;
  for i in 1..1000 loop
    cards:=aamix_private.draw_pack(); assert cards->>0='0100';
    for slot in 0..4 loop
      assert exists(select 1 from aamix_private.reward_catalog where code=cards->>slot and not is_promotional),'Promo entered pack';
      if slot>0 then assert cards->>slot<>'0100'; end if;
    end loop;
  end loop;
  assert not has_function_privilege('anon','public.aamix_claim_mission(text)','execute');
  assert not has_function_privilege('anon','aamix_private.claim_mission(text)','execute');
  assert not has_function_privilege('anon','aamix_private.missions_status()','execute');
  assert not has_table_privilege('authenticated','public.aamix_mission_claims','insert');
  assert not has_table_privilege('authenticated','aamix_private.gift_code_rewards','select');
  assert (select not prosecdef from pg_proc where oid='public.aamix_inventory()'::regprocedure);
  assert (select not prosecdef from pg_proc where oid='public.aamix_claim_mission(text)'::regprocedure);
end $$;
select 'PASS: daily PLAY1 preserved, daily WIN1, lifetime PLAY10, retroactive receipts, independent claims, Chile midnight/session timezone,20 retries, old gifts preserved,AAMIXTC1pack,Girabl40/12,auth/RLS,atomic overflow,1000promo-free packs;all fixtures rolled back' as validation;
rollback;
