-- Run after aamix_challenges_and_missions_v0140.sql. Every fixture rolls back.
-- Synthetic UUIDs/invalid mailboxes only. No mail, claim or redemption for real users.
begin;
set local plpgsql.check_asserts=on;
set local timezone='Pacific/Honolulu';
create temporary table aamix_v014_users(label text primary key,uid uuid not null default gen_random_uuid());
insert into aamix_v014_users(label) values('a'),('b'),('legacy'),('overflow'),('midnight'),('unconfirmed'),('anonymous');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@aamix-v014-qa.invalid',case when label='unconfirmed' then null else now() end,now(),now(),label='anonymous'
  from pg_temp.aamix_v014_users;
select set_config('aamix.v014_a',(select uid::text from pg_temp.aamix_v014_users where label='a'),true);
select set_config('aamix.v014_b',(select uid::text from pg_temp.aamix_v014_users where label='b'),true);
select set_config('aamix.v014_legacy',(select uid::text from pg_temp.aamix_v014_users where label='legacy'),true);
select set_config('aamix.v014_overflow',(select uid::text from pg_temp.aamix_v014_users where label='overflow'),true);
select set_config('aamix.v014_midnight',(select uid::text from pg_temp.aamix_v014_users where label='midnight'),true);
select set_config('aamix.v014_unconfirmed',(select uid::text from pg_temp.aamix_v014_users where label='unconfirmed'),true);
select set_config('aamix.v014_anonymous',(select uid::text from pg_temp.aamix_v014_users where label='anonymous'),true);
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select u.uid,d.id,d.name,d.cover,d.cards from pg_temp.aamix_v014_users u cross join aamix_private.base_decks d
  where u.label in('a','b','legacy','overflow','midnight') and d.id in('maago','kajido');
insert into public.aamix_collection(user_id,code,quantity)
  select u.uid,e->>'codigo',(e->>'cantidad')::integer from pg_temp.aamix_v014_users u cross join aamix_private.base_decks d
  cross join lateral jsonb_array_elements(d.cards) e where u.label in('a','b','legacy','overflow','midnight') and d.id='maago';
insert into public.aamix_rewards_state(user_id,packs)
  select uid,case label when 'legacy' then 7 when 'overflow' then 2147483647 else 0 end from pg_temp.aamix_v014_users
  where label in('a','b','legacy','overflow','midnight');
-- A starts with nine historical completed games, eight wins. All precede today.
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',now()-(n+2)*interval '1 day',now()-(n+1)*interval '1 day',case n when 9 then 'defeat' else 'victory' end
  from pg_temp.aamix_v014_users cross join generate_series(1,9) s(n) where label='a';
-- Previously paid PLAY10 five packs, and two dated WIN1 claims, must remain paid.
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',now()-(n+2)*interval '1 day',now()-(n+1)*interval '1 day','victory'
  from pg_temp.aamix_v014_users cross join generate_series(1,10) s(n) where label in('legacy','overflow');
insert into public.aamix_mission_claims(user_id,mission_id,period_key,reward_packs)
  select uid,'play_ten','lifetime',5 from pg_temp.aamix_v014_users where label='legacy';
insert into public.aamix_mission_claims(user_id,mission_id,period_key,reward_packs)
  select uid,'win_one',((now() at time zone 'America/Santiago')::date-n)::text,1
  from pg_temp.aamix_v014_users cross join generate_series(1,2) s(n) where label='legacy';
-- One legacy daily claim today. Updating mission definitions cannot pay it again.
insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id,claimed_at)
  select uid,(now() at time zone 'America/Santiago')::date,(select match_id from public.aamix_match_receipts where user_id=uid limit 1),now()
  from pg_temp.aamix_v014_users where label='legacy';
-- WIN1 is now lifetime; Chile midnight still governs only PLAY1.
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago')-interval '5 minutes',
    ((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago')-interval '1 microsecond','victory'
  from pg_temp.aamix_v014_users where label='midnight';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'maago',((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago')-interval '3 minutes',
    ((now() at time zone 'America/Santiago')::date::timestamp at time zone 'America/Santiago'),'defeat'
  from pg_temp.aamix_v014_users where label='midnight';

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v014_a'),'role','authenticated')::text,true);
do $$
declare r jsonb; status jsonb; before jsonb; req uuid; alt_req uuid; random_req uuid; mid uuid; alt_mid uuid;
  i integer; stage integer; slot integer; expected text[]:=array['papito','flaan','kajido','maago','girabl'];
  prizes integer[]:=array[1,1,1,2,3]; balance integer:=0; receipts bigint;
begin
  r:=public.aamix_inventory();
  assert jsonb_array_length(r->'missions')=4 and jsonb_array_length(r->'challenges')=5;
  assert r->'mission'=(r->'missions'->0)-'scope','Old mission alias changed';
  assert r->'missions'->0->>'scope'='daily' and (r->'missions'->0->>'progress')::integer=0;
  assert r->'missions'->1->>'scope'='lifetime' and r->'missions'->1->'day'='null'::jsonb;
  assert (r->'missions'->1->>'progress')::integer=1 and (r->'missions'->2->>'progress')::integer=9 and (r->'missions'->3->>'progress')::integer=8;
  assert (r->'missions'->2->>'reward_packs')::integer=3 and (r->'missions'->3->>'reward_packs')::integer=5;
  assert (r->>'packs')::integer=0 and (select count(*) from public.aamix_challenge_completions)=0;
  for stage in 1..5 loop
    status:=r->'challenges'->(stage-1);
    assert (status->>'stage')::integer=stage and status->>'deck_id'=expected[stage];
    assert (status->>'reward_packs')::integer=prizes[stage] and (status->>'unlocked')::boolean=(stage=1);
    assert status->>'completed'='false' and status->>'reward_claimed'='false';
  end loop;
  begin perform public.aamix_claim_mission('play_ten'); raise exception 'Nine games accepted as ten'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_claim_mission('win_ten'); raise exception 'Eight wins accepted as ten'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_claim_mission('play_one'); raise exception 'Old match counted for today'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_claim_mission('forged'); raise exception 'Forged mission accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_claim_mission(null); raise exception 'NULL mission accepted'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_claim_mission('win_one'); balance:=1;
  assert r->>'already_claimed'='false' and (r->>'packs')::integer=balance;
  for i in 1..20 loop r:=public.aamix_claim_mission('win_one'); assert r->>'already_claimed'='true' and (r->>'packs')::integer=balance; end loop;
  for stage in 2..5 loop
    begin perform public.aamix_begin_challenge_match(gen_random_uuid(),'maago',stage); raise exception 'Locked stage accepted'; exception when invalid_parameter_value then null; end;
  end loop;
  foreach stage in array array[-1,0,6,2147483647] loop
    begin perform public.aamix_begin_challenge_match(gen_random_uuid(),'maago',stage); raise exception 'Invalid stage accepted'; exception when invalid_parameter_value then null; end;
  end loop;
  begin perform public.aamix_begin_challenge_match(gen_random_uuid(),'maago',null); raise exception 'NULL stage accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_begin_challenge_match(null,'maago',1); raise exception 'NULL UUID accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_begin_challenge_match(gen_random_uuid(),null,1); raise exception 'NULL deck accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_begin_challenge_match(gen_random_uuid(),'papito',1); raise exception 'Unowned deck accepted'; exception when invalid_parameter_value then null; end;
  -- Defeat counts for PLAY1/PLAY10, never unlocks the next stage or grants its prize.
  r:=public.aamix_begin_challenge_match(gen_random_uuid(),'maago',1); mid:=(r->>'match_id')::uuid;
  assert (r->'missions'->2->>'progress')::integer=9,'Unfinished receipt counted';
  r:=public.aamix_finish_match(mid,'defeat');
  assert (r->>'packs')::integer=balance and (r->>'challenge_reward_packs')::integer=0;
  assert r->'challenges'->1->>'unlocked'='false' and r->'challenges'->0->>'completed'='false';
  assert (r->'missions'->2->>'progress')::integer=10 and (r->'missions'->3->>'progress')::integer=8;
  for i in 1..20 loop r:=public.aamix_finish_match(mid,'defeat'); assert (r->>'packs')::integer=balance and (r->>'challenge_reward_packs')::integer=0; end loop;
  begin perform public.aamix_finish_match(mid,'victory'); raise exception 'Defeat changed to victory'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_claim_daily_mission(); balance:=balance+1;
  assert (r->>'packs')::integer=balance and r->>'mission_id'='play_one';
  r:=public.aamix_claim_mission('play_ten'); balance:=balance+3;
  assert (r->>'packs')::integer=balance and (r->>'reward_packs')::integer=3;
  for i in 1..20 loop
    r:=public.aamix_claim_mission('play_ten'); assert r->>'already_claimed'='true' and (r->>'packs')::integer=balance;
    r:=public.aamix_claim_mission('play_one'); assert r->>'already_claimed'='true' and (r->>'packs')::integer=balance;
  end loop;
  -- A random victory is never a challenge completion; modes cannot reuse a UUID.
  random_req:=gen_random_uuid(); r:=public.aamix_begin_match(random_req,'maago'); mid:=(r->>'match_id')::uuid;
  assert r->'challenge_stage'='null'::jsonb;
  r:=public.aamix_finish_match(mid,'victory');
  assert (r->>'packs')::integer=balance and r->'challenges'->1->>'unlocked'='false';
  assert (select count(*) from public.aamix_challenge_completions)=0;
  begin perform public.aamix_begin_challenge_match(random_req,'maago',1); raise exception 'Random receipt became challenge'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_begin_match(random_req,'kajido'); raise exception 'Request deck changed'; exception when invalid_parameter_value then null; end;
  -- Clear all stages in exact order, including two started attempts, retries and replays.
  for stage in 1..5 loop
    req:=gen_random_uuid(); alt_req:=gen_random_uuid();
    r:=public.aamix_begin_challenge_match(req,'maago',stage); mid:=(r->>'match_id')::uuid;
    assert (r->>'challenge_stage')::integer=stage and r->'challenge_opponent'->>'id'=expected[stage];
    assert (select sum((c->>'cantidad')::integer) from jsonb_array_elements(r->'challenge_opponent'->'cartas') c)=40,'Opponent not exact40';
    for i in 1..20 loop
      before:=public.aamix_begin_challenge_match(req,'maago',stage);
      assert (before->>'match_id')::uuid=mid and before->'challenge_opponent'=r->'challenge_opponent','Retry snapshot/receipt changed';
    end loop;
    begin perform public.aamix_begin_match(req,'maago'); raise exception 'Challenge receipt became random'; exception when invalid_parameter_value then null; end;
    begin perform public.aamix_begin_challenge_match(req,'kajido',stage); raise exception 'Challenge player deck changed'; exception when invalid_parameter_value then null; end;
    begin perform public.aamix_begin_challenge_match(req,'maago',case when stage=5 then 4 else stage+1 end); raise exception 'Challenge stage changed'; exception when invalid_parameter_value then null; end;
    before:=public.aamix_begin_challenge_match(alt_req,'maago',stage); alt_mid:=(before->>'match_id')::uuid;
    r:=public.aamix_finish_match(mid,'victory'); balance:=balance+prizes[stage];
    assert (r->>'packs')::integer=balance and (r->>'challenge_reward_packs')::integer=prizes[stage] and r->>'challenge_already_completed'='false';
    assert r->'challenges'->(stage-1)->>'completed'='true' and r->'challenges'->(stage-1)->>'reward_claimed'='true';
    if stage<5 then assert r->'challenges'->stage->>'unlocked'='true'; end if;
    receipts:=(select count(*) from public.aamix_match_receipts);
    for i in 1..20 loop
      r:=public.aamix_finish_match(mid,'victory');
      assert (r->>'packs')::integer=balance and (r->>'challenge_reward_packs')::integer=0 and r->>'challenge_already_completed'='true';
      assert (select count(*) from public.aamix_match_receipts)=receipts,'Finish created a second receipt';
    end loop;
    begin perform public.aamix_finish_match(mid,'defeat'); raise exception 'Victory changed to defeat'; exception when invalid_parameter_value then null; end;
    r:=public.aamix_finish_match(alt_mid,'victory');
    assert (r->>'packs')::integer=balance and (r->>'challenge_reward_packs')::integer=0,'Parallel-started attempt paid twice';
    r:=public.aamix_begin_challenge_match(gen_random_uuid(),'kajido',stage);
    r:=public.aamix_finish_match((r->>'match_id')::uuid,'victory');
    assert (r->>'packs')::integer=balance and (r->>'challenge_reward_packs')::integer=0,'Replay paid twice';
    assert (select count(*) from public.aamix_challenge_completions)=stage;
    if stage=1 then
      assert (r->'missions'->3->>'progress')::integer=10,'Challenge wins omitted from missions';
      r:=public.aamix_claim_mission('win_ten'); balance:=balance+5;
      assert (r->>'packs')::integer=balance and (r->>'reward_packs')::integer=5;
      for i in 1..20 loop r:=public.aamix_claim_mission('win_ten'); assert r->>'already_claimed'='true' and (r->>'packs')::integer=balance; end loop;
    end if;
  end loop;
  assert balance=18 and (r->>'packs')::integer=18;
  assert not exists(select 1 from jsonb_array_elements(r->'challenges') c where c->>'unlocked'<>'true' or c->>'completed'<>'true');
  assert (select sum(reward_packs) from public.aamix_challenge_completions)=8;
  assert (select count(*) from public.aamix_mission_claims)=3 and (select sum(reward_packs) from public.aamix_mission_claims)=9;
  assert (select count(*) from public.aamix_daily_missions where claimed_at is not null)=1;
  assert not has_table_privilege('authenticated','public.aamix_challenge_completions','insert');
  assert not has_table_privilege('authenticated','public.aamix_challenge_completions','update');
  begin update public.aamix_match_receipts set challenge_stage=5 where match_id=mid; raise exception 'Receipt metadata client-writable'; exception when insufficient_privilege then null; end;
  begin insert into public.aamix_challenge_completions(user_id,stage,winning_match_id,reward_packs) values(auth.uid(),1,mid,1); raise exception 'Completion client-writable'; exception when insufficient_privilege then null; end;
  perform set_config('aamix.v014_other_receipt',mid::text,true);
end $$;

-- A second UUID starts locked independently and cannot see or finish A's receipt.
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v014_b'),'role','authenticated')::text,true);
do $$
declare r jsonb; req uuid:=gen_random_uuid(); mid uuid;
begin
  r:=public.aamix_inventory();
  assert (select count(*) from public.aamix_challenge_completions)=0 and (select count(*) from public.aamix_match_receipts)=0;
  assert r->'challenges'->0->>'unlocked'='true' and r->'challenges'->1->>'unlocked'='false' and (r->>'packs')::integer=0;
  begin perform public.aamix_finish_match(current_setting('aamix.v014_other_receipt')::uuid,'victory'); raise exception 'Cross-UUID finish accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_finish_match(gen_random_uuid(),'victory'); raise exception 'Invented receipt accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_begin_challenge_match(req,'maago',2); raise exception 'Global unlock leaked'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_begin_challenge_match(req,'maago',1); mid:=(r->>'match_id')::uuid;
  begin perform public.aamix_finish_match(mid,null); raise exception 'NULL result accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_finish_match(mid,'cancelled'); raise exception 'Incomplete result accepted'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_finish_match(mid,'victory');
  assert (r->>'packs')::integer=1 and (r->>'challenge_reward_packs')::integer=1 and (select count(*) from public.aamix_challenge_completions)=1;
  assert (r->'missions'->2->>'progress')::integer=1 and (r->'missions'->3->>'progress')::integer=1;
end $$;

-- Previously paid amounts/claim keys stay intact; WIN1 can never be paid again.
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v014_legacy'),'role','authenticated')::text,true);
do $$
declare r jsonb; original jsonb; i integer;
begin
  original:=public.aamix_inventory();
  assert (original->>'packs')::integer=7 and original->'missions'->1->>'claimed'='true' and original->'missions'->2->>'claimed'='true';
  assert (original->'missions'->2->>'reward_packs')::integer=3 and original->'missions'->3->>'claimed'='false';
  for i in 1..20 loop
    r:=public.aamix_claim_mission('win_one'); assert r->>'already_claimed'='true' and (r->>'reward_packs')::integer=1 and (r->>'packs')::integer=7;
    r:=public.aamix_claim_mission('play_ten'); assert r->>'already_claimed'='true' and (r->>'reward_packs')::integer=5 and (r->>'packs')::integer=7;
    r:=public.aamix_claim_daily_mission(); assert r->>'already_claimed'='true' and (r->>'packs')::integer=7;
  end loop;
  assert (select count(*) from public.aamix_mission_claims where mission_id='win_one')=2;
  assert not exists(select 1 from public.aamix_mission_claims where mission_id='win_one' and period_key='lifetime');
  assert (select reward_packs from public.aamix_mission_claims where mission_id='play_ten')=5;
  r:=public.aamix_claim_mission('win_ten');
  assert (r->>'packs')::integer=12 and (r->>'reward_packs')::integer=5 and r->>'already_claimed'='false';
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v014_midnight'),'role','authenticated')::text,true);
do $$
declare r jsonb; old_mid uuid;
begin
  r:=public.aamix_inventory();
  assert (r->'mission'->>'progress')::integer=1 and (r->'missions'->1->>'progress')::integer=1;
  assert (r->'missions'->2->>'progress')::integer=2 and (r->'missions'->3->>'progress')::integer=1;
  assert r->'mission'->>'day'=(now() at time zone 'America/Santiago')::date::text;
  r:=public.aamix_claim_mission('win_one'); assert (r->>'packs')::integer=1,'Yesterday victory not counted for lifetime WIN1';
  r:=public.aamix_claim_daily_mission(); assert (r->>'packs')::integer=2;
  select match_id into old_mid from public.aamix_match_receipts where result='victory';
  r:=public.aamix_finish_match(old_mid,'victory');
  assert (select count(*) from public.aamix_daily_missions)=1 and (r->>'packs')::integer=2,'Old finish created a new daily reward';
end $$;

-- Failure adding packs must undo receipt completion, daily progress and unlock atomically.
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v014_overflow'),'role','authenticated')::text,true);
do $$
declare r jsonb; original jsonb; mid uuid; m text;
begin
  r:=public.aamix_begin_challenge_match(gen_random_uuid(),'maago',1); mid:=(r->>'match_id')::uuid; original:=public.aamix_inventory();
  begin perform public.aamix_finish_match(mid,'victory'); raise exception 'Challenge overflow accepted'; exception when numeric_value_out_of_range then null; end;
  assert public.aamix_inventory()=original,'Challenge overflow partially committed';
  assert (select result from public.aamix_match_receipts where match_id=mid) is null;
  assert (select count(*) from public.aamix_challenge_completions)=0 and (select count(*) from public.aamix_daily_missions)=0;
  foreach m in array array['win_one','play_ten','win_ten'] loop
    begin perform public.aamix_claim_mission(m); raise exception 'Mission overflow accepted'; exception when numeric_value_out_of_range then null; end;
    assert public.aamix_inventory()=original and (select count(*) from public.aamix_mission_claims)=0;
  end loop;
  -- A defeat still finishes safely without an automatic award at a full balance.
  r:=public.aamix_finish_match(mid,'defeat'); original:=public.aamix_inventory();
  begin perform public.aamix_claim_daily_mission(); raise exception 'Daily overflow accepted'; exception when numeric_value_out_of_range then null; end;
  assert public.aamix_inventory()=original and (select count(*) from public.aamix_daily_missions where claimed_at is not null)=0;
end $$;
reset role;
-- After reducing only this synthetic balance, the aborted stage remains earnable once.
update public.aamix_rewards_state set packs=0 where user_id=current_setting('aamix.v014_overflow')::uuid;
set local role authenticated;
do $$
declare r jsonb; mid uuid;
begin
  r:=public.aamix_begin_challenge_match(gen_random_uuid(),'maago',1); mid:=(r->>'match_id')::uuid;
  r:=public.aamix_finish_match(mid,'victory');
  assert (r->>'packs')::integer=1 and (r->>'challenge_reward_packs')::integer=1 and r->'challenges'->1->>'unlocked'='true';
end $$;

-- Mutation guards require a real nonanonymous account with confirmed email.
do $$
declare label text;
begin
  foreach label in array array['unconfirmed','anonymous'] loop
    perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v014_'||label),'role','authenticated')::text,true);
    begin perform public.aamix_begin_challenge_match(gen_random_uuid(),'maago',1); raise exception 'Unverified challenge accepted'; exception when invalid_authorization_specification then null; end;
    begin perform public.aamix_finish_match(gen_random_uuid(),'victory'); raise exception 'Unverified finish accepted'; exception when invalid_authorization_specification then null; end;
    begin perform public.aamix_claim_mission('win_ten'); raise exception 'Unverified mission accepted'; exception when invalid_authorization_specification then null; end;
    assert (select count(*) from public.aamix_challenge_completions)=0;
  end loop;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  begin perform public.aamix_begin_challenge_match(gen_random_uuid(),'maago',1); raise exception 'Nonexistent UUID accepted'; exception when invalid_authorization_specification then null; end;
  perform set_config('request.jwt.claims','{}',true);
  begin perform public.aamix_begin_challenge_match(gen_random_uuid(),'maago',1); raise exception 'Missing UUID accepted'; exception when invalid_authorization_specification then null; end;
  begin perform public.aamix_inventory(); raise exception 'Inventory without UUID accepted'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;

-- Schema-level guards, invoker wrappers, privileges and unchanged pack pool.
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v014_a'),'role','authenticated')::text,true);
do $$
declare f regprocedure; p jsonb; i integer; slot integer; uid uuid; r uuid;
begin
  foreach f in array array['public.aamix_inventory()'::regprocedure,'public.aamix_begin_challenge_match(uuid,text,integer)'::regprocedure,
    'public.aamix_begin_match(uuid,text)'::regprocedure,'public.aamix_finish_match(uuid,text)'::regprocedure,'public.aamix_claim_mission(text)'::regprocedure] loop
    assert not (select prosecdef from pg_proc where oid=f),'Public definer exposed';
    assert not has_function_privilege('anon',f,'execute') and has_function_privilege('authenticated',f,'execute');
  end loop;
  assert (select relrowsecurity from pg_class where oid='public.aamix_challenge_completions'::regclass);
  assert not has_function_privilege('authenticated','aamix_private.lock_rewards()','execute');
  assert not has_table_privilege('anon','public.aamix_challenge_completions','select');
  assert (select count(*) from aamix_private.gift_code_rewards)=8 and (select count(*) from aamix_private.base_decks)=5;
  assert (select count(*) from aamix_private.reward_catalog where not is_promotional)=35;
  select u.uid into uid from pg_temp.aamix_v014_users u where label='b';
  begin
    insert into public.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent) values(uid,gen_random_uuid(),'maago',1,'{}'::jsonb);
    raise exception 'Malformed challenge snapshot accepted';
  exception when check_violation then null; end;
  begin
    insert into public.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent) values(uid,gen_random_uuid(),'maago',1,null);
    raise exception 'Missing snapshot accepted';
  exception when check_violation then null; end;
  begin
    insert into public.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent) values(uid,gen_random_uuid(),'maago',1,'{"id":"girabl","cartas":[]}'::jsonb);
    raise exception 'Wrong opponent accepted';
  exception when check_violation then null; end;
  for i in 1..1000 loop
    p:=aamix_private.draw_pack(); assert jsonb_array_length(p)=5 and p->>0='0100';
    for slot in 0..4 loop
      assert exists(select 1 from aamix_private.reward_catalog where code=p->>slot and not is_promotional),'Promotional entered pack';
      if slot>0 then assert p->>slot<>'0100','Resource outside first slot'; end if;
    end loop;
  end loop;
end $$;
select 'PASS: five ordered UUID-specific once-only challenges, locked skips and loss, fixed40-card opponents, 20 retries per start/finish/claim, replays and parallel-started attempts, random receipt spoof prevention, 4 independent missions, historical WIN1/PLAY10 paid amounts preserved, Chile midnight, RLS/auth/ACL, atomic overflow rollback, 1000 promo-free server packs; ALL fixtures rolled back' as validation;
rollback;
