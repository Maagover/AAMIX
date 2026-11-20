-- Integration test for the 0.10.1 schema (original 0.10.0 regression plus pack exclusion). EVERYTHING rolls back.
-- Synthetic random UUIDs only. Never delete, sign in as, or award a real account.
begin;
create temporary table aamix_reward_qa_users(label text primary key, uid uuid not null default gen_random_uuid());
create temporary table aamix_reward_qa_summary(histogram jsonb, special_count integer, rare_count integer);
insert into aamix_reward_qa_users(label) values('a'),('b'),('unconfirmed'),('anonymous'),('overflow');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@aamix-qa.invalid',case when label='unconfirmed' then null else now() end,now(),now(),label='anonymous' from aamix_reward_qa_users;
select set_config('aamix.qa_a',(select uid::text from aamix_reward_qa_users where label='a'),true);
select set_config('aamix.qa_b',(select uid::text from aamix_reward_qa_users where label='b'),true);
select set_config('aamix.qa_unconfirmed',(select uid::text from aamix_reward_qa_users where label='unconfirmed'),true);
select set_config('aamix.qa_anonymous',(select uid::text from aamix_reward_qa_users where label='anonymous'),true);
select set_config('aamix.qa_overflow',(select uid::text from aamix_reward_qa_users where label='overflow'),true);
-- Overflow deliberately aborts an award AFTER its redemption row was inserted.
insert into public.aamix_collection(user_id,code,quantity) select uid,'0100',2147483647 from aamix_reward_qa_users where label='overflow';
insert into public.aamix_rewards_state(user_id,packs) select uid,1 from aamix_reward_qa_users where label='overflow';
-- An old finished receipt must not satisfy tomorrow's mission when replayed.
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select u.uid,d.id,d.name,d.cover,d.cards from aamix_reward_qa_users u cross join aamix_private.base_decks d where u.label='b' and d.id='papito';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,'a1000000-0000-4000-8000-000000000090','papito',now()-interval '2 days',now()-interval '1 day','defeat' from aamix_reward_qa_users where label='b';

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.qa_a'),'role','authenticated')::text,true);
do $$
declare r jsonb; original jsonb; mid uuid; opened jsonb; second jsonb; opening_id uuid; cards jsonb; before_count integer; i integer; t text;
begin
  r:=public.aamix_inventory();
  assert r->'gift'='null'::jsonb;
  assert r->'collection'='{}'::jsonb and r->'decks'='[]'::jsonb;
  assert (r->>'packs')::integer=0 and (r->'mission'->>'progress')::integer=0;
  assert r->'profile'->'avatar_code'='null'::jsonb and r->'pending_opening'='null'::jsonb;
  assert r->'mission'->>'day'=((now() at time zone 'America/Santiago')::date)::text;
  begin perform public.aamix_set_avatar('0100'); raise exception 'Resource avatar accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_set_avatar('0119'); raise exception 'Event avatar accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_set_avatar(null); raise exception 'NULL avatar accepted'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_set_avatar('0108');
  assert r->'profile'->>'avatar_code'='0108';
  assert public.aamix_inventory()=r,'Avatar not persistent';
  begin perform public.aamix_claim_starter('maago'); raise exception 'Maago accepted as starter'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_redeem_code('FAKE'); raise exception 'Invalid code accepted'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_redeem_code(' m4z0m44g0 ');
  assert r->>'already_redeemed'='false';
  assert r->'gift'='null'::jsonb,'Gift code consumed starter reward';
  assert r->'decks'->0->>'id'='maago' and r->'decks'->0->>'nombre'='Mazo Maagover';
  assert (select sum(value::integer) from jsonb_each_text(r->'collection'))=40;
  assert (r->'collection'->>'0100')::integer=15;
  original:=r-'already_redeemed'-'reward_deck_id';
  for i in 1..20 loop
    r:=public.aamix_redeem_code('M4Z0M44G0');
    assert r->>'already_redeemed'='true';
    assert r-'already_redeemed'-'reward_deck_id'=original,'Retry duplicated gift';
  end loop;
  r:=public.aamix_claim_starter('kajido');
  assert r->>'already_claimed'='false';
  assert (select sum(value::integer) from jsonb_each_text(r->'collection'))=80;
  assert (r->'collection'->>'0100')::integer=33 and jsonb_array_length(r->'decks')=2;
  begin perform public.aamix_claim_daily_mission(); raise exception 'Unfinished mission claimed'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_begin_match('a1000000-0000-4000-8000-000000000001','papito'); raise exception 'Unowned deck accepted'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_begin_match('a1000000-0000-4000-8000-000000000001','maago');
  mid:=(r->>'match_id')::uuid;
  for i in 1..20 loop
    r:=public.aamix_begin_match('a1000000-0000-4000-8000-000000000001','maago');
    assert (r->>'match_id')::uuid=mid,'Retry made another match';
  end loop;
  begin perform public.aamix_begin_match('a1000000-0000-4000-8000-000000000001','kajido'); raise exception 'Mismatched request deck accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_finish_match(mid,'cancelled'); raise exception 'Cancelled match accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_finish_match('a1000000-0000-4000-8000-000000000002','victory'); raise exception 'Invented receipt accepted'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_finish_match(mid,'victory');
  assert (r->'mission'->>'progress')::integer=1 and r->'mission'->>'claimed'='false';
  assert (r->>'packs')::integer=0,'Completion awarded before explicit claim';
  original:=r;
  assert public.aamix_finish_match(mid,'victory')=original;
  begin perform public.aamix_finish_match(mid,'defeat'); raise exception 'Receipt outcome changed'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_claim_daily_mission();
  assert (r->>'packs')::integer=1 and r->'mission'->>'claimed'='true' and r->>'already_claimed'='false';
  for i in 1..20 loop
    r:=public.aamix_claim_daily_mission();
    assert (r->>'packs')::integer=1 and r->>'already_claimed'='true';
  end loop;
  r:=public.aamix_begin_match('a1000000-0000-4000-8000-000000000003','kajido');
  r:=public.aamix_finish_match((r->>'match_id')::uuid,'defeat');
  assert (r->>'packs')::integer=1;
  r:=public.aamix_claim_daily_mission();
  assert (r->>'packs')::integer=1 and r->>'already_claimed'='true','Second match granted same-day reward twice';
  before_count:=(select sum(value::integer) from jsonb_each_text(r->'collection'));
  r:=public.aamix_open_pack('a1000000-0000-4000-8000-000000000010');
  opened:=r->'opening'; opening_id:=(opened->>'opening_id')::uuid; cards:=opened->'cards';
  assert jsonb_array_length(cards)=5 and cards->>0='0100';
  for i in 1..4 loop assert cards->>i<>'0100','Resource outside slot1'; end loop;
  assert (r->>'packs')::integer=0 and r->'pending_opening'=opened;
  assert (select sum(value::integer) from jsonb_each_text(r->'collection'))=before_count+5;
  for i in 1..20 loop
    r:=public.aamix_open_pack('a1000000-0000-4000-8000-000000000010');
    assert r->'opening'=opened and (r->>'packs')::integer=0;
  end loop;
  second:=public.aamix_open_pack('a1000000-0000-4000-8000-000000000011');
  assert second->'opening'=opened,'Second client did not resume pending opening';
  assert public.aamix_inventory()->'pending_opening'=opened,'Reconnect lost exact cards';
  r:=public.aamix_acknowledge_opening(opening_id);
  assert r->'pending_opening'='null'::jsonb;
  assert public.aamix_acknowledge_opening(opening_id)=r,'Acknowledge is not idempotent';
  r:=public.aamix_open_pack('a1000000-0000-4000-8000-000000000011');
  assert r->'opening'->'cards'=cards and r->'opening'->'revealed_at'<>'null'::jsonb;
  assert (r->>'packs')::integer=0 and r->'pending_opening'='null'::jsonb,'Alias retry resurrected or spent another pack';
  begin perform public.aamix_open_pack('a1000000-0000-4000-8000-000000000012'); raise exception 'Opened nonexistent pack'; exception when invalid_parameter_value then null; end;
  -- All public writes remain denied, even to the caller's own UUID.
  begin update public.aamix_rewards_state set packs=999; raise exception 'Forged packs'; exception when insufficient_privilege then null; end;
  begin insert into public.aamix_collection(user_id,code,quantity) values(auth.uid(),'0100',999); raise exception 'Forged collection'; exception when insufficient_privilege then null; end;
  begin update public.aamix_daily_missions set claimed_at=null; raise exception 'Reset mission'; exception when insufficient_privilege then null; end;
  begin update public.aamix_pack_openings set cards='["0100","0100","0100","0100","0100"]'; raise exception 'Forged pack'; exception when insufficient_privilege then null; end;
  begin delete from public.aamix_code_redemptions; raise exception 'Reset code'; exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.qa_b'),'role','authenticated')::text,true);
do $$
declare r jsonb; mid uuid;
begin
  r:=public.aamix_inventory();
  assert r->'collection'='{}'::jsonb and (r->>'packs')::integer=0 and r->'profile'->'avatar_code'='null'::jsonb;
  assert (select count(*) from public.aamix_code_redemptions)=0 and (select count(*) from public.aamix_pack_openings)=0;
  assert (select count(*) from public.aamix_pack_requests)=0 and (select count(*) from public.aamix_daily_missions)=0,'Cross-UUID read';
  select match_id into mid from public.aamix_match_receipts where request_id='a1000000-0000-4000-8000-000000000090';
  r:=public.aamix_finish_match(mid,'defeat');
  assert (r->'mission'->>'progress')::integer=0,'Yesterday replay satisfied today';
  begin perform public.aamix_claim_daily_mission(); raise exception 'Yesterday replay granted pack'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_begin_match('a1000000-0000-4000-8000-000000000001','papito');
  r:=public.aamix_finish_match((r->>'match_id')::uuid,'defeat');
  assert (r->'mission'->>'progress')::integer=1,'Defeat did not complete mission';
  r:=public.aamix_claim_daily_mission();
  assert (r->>'packs')::integer=1,'Defeat did not reward';
  r:=public.aamix_redeem_code('M4Z0M44G0');
  assert r->>'already_redeemed'='false','Code incorrectly global instead of per UUID';
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.qa_overflow'),'role','authenticated')::text,true);
do $$
begin
  begin perform public.aamix_redeem_code('M4Z0M44G0'); raise exception 'Missing intentional overflow'; exception when numeric_value_out_of_range then null; end;
  assert (select count(*) from public.aamix_code_redemptions)=0,'Partial code redemption survived failure';
  assert (select count(*) from public.aamix_owned_decks)=0,'Partial deck award survived failure';
  assert (select count(*) from public.aamix_collection)=1,'Partial collection survived failed deck award';
  begin perform public.aamix_open_pack('a1000000-0000-4000-8000-000000000010'); raise exception 'Missing intentional pack overflow'; exception when numeric_value_out_of_range then null; end;
  assert (select packs from public.aamix_rewards_state)=1,'Pack spent despite failed collection';
  assert (select count(*) from public.aamix_pack_openings)=0,'Failed opening persisted';
  assert (select count(*) from public.aamix_pack_requests)=0,'Failed request persisted';
end $$;

do $$
declare label text;
begin
  foreach label in array array['unconfirmed','anonymous'] loop
    perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.qa_'||label),'role','authenticated')::text,true);
    begin perform public.aamix_set_avatar('0108'); raise exception 'Unverified avatar write'; exception when invalid_authorization_specification then null; end;
    begin perform public.aamix_redeem_code('M4Z0M44G0'); raise exception 'Unverified gift'; exception when invalid_authorization_specification then null; end;
    begin perform public.aamix_claim_daily_mission(); raise exception 'Unverified mission'; exception when invalid_authorization_specification then null; end;
    begin perform public.aamix_open_pack(gen_random_uuid()); raise exception 'Unverified opening'; exception when invalid_authorization_specification then null; end;
    begin perform public.aamix_begin_match(gen_random_uuid(),'maago'); raise exception 'Unverified match'; exception when invalid_authorization_specification then null; end;
  end loop;
  perform set_config('request.jwt.claims','{}',true);
  begin perform public.aamix_inventory(); raise exception 'Missing auth accepted'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;

-- Validate all catalogue choices and an actual random sample using server draws.
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.qa_a'),'role','authenticated')::text,true);
do $$
declare c record; cards jsonb; i integer; j integer; special_count integer:=0; rare_count integer:=0; normal_seen text[]:='{}'; last_code text; histogram jsonb:='{}'::jsonb;
begin
  for c in select code from aamix_private.reward_catalog where card_class='Aliado' and not is_promotional loop
    assert public.aamix_set_avatar(c.code)->'profile'->>'avatar_code'=c.code;
  end loop;
  assert (select count(*) from aamix_private.reward_catalog)=41;
  assert (select count(*) from aamix_private.reward_catalog where special_weight>0)=9;
  assert (select sum(special_weight) from aamix_private.reward_catalog)=100;
  begin
    insert into public.aamix_pack_openings(user_id,request_id,cards)
      values(current_setting('aamix.qa_b')::uuid,gen_random_uuid(),'["0100","01a","0104","0120","0105"]'::jsonb);
    raise exception 'Database accepted a new pack with a promotional card';
  exception when check_violation then null; end;

  assert (select count(*) from aamix_private.reward_catalog where is_promotional)=6;
  assert (select count(*) from aamix_private.reward_catalog where not is_promotional)=35;
  assert (select count(*) from aamix_private.reward_catalog where not is_promotional and card_class<>'Recurso' and special_weight=0)=25;
  for i in 1..10000 loop
    cards:=aamix_private.draw_pack();
    assert cards->>0='0100';
    assert not (cards ?| array['01a','01b','01c','01d','01e','01f']), 'Promotional card in pack';
    for j in 1..3 loop
      assert exists(select 1 from aamix_private.reward_catalog where code=cards->>j and card_class<>'Recurso' and special_weight=0 and not is_promotional),'Non-normal slot2-4';
    end loop;
    last_code:=cards->>4;
    histogram:=jsonb_set(histogram,array[last_code],to_jsonb(coalesce((histogram->>last_code)::integer,0)+1));
    if exists(select 1 from aamix_private.reward_catalog where code=last_code and special_weight>0) then
      special_count:=special_count+1;
      if last_code in ('0105','0103','0115','0119') then rare_count:=rare_count+1; end if;
    else
      assert last_code<>'0100';
      if not last_code=any(normal_seen) then normal_seen:=array_append(normal_seen,last_code); end if;
    end if;
  end loop;
  assert special_count between 2700 and 3300,'Special overall frequency outside broad 30% tolerance';
  assert rare_count between 400 and 800,'Four rare combined overall frequency outside broad 6% tolerance';
  assert array_length(normal_seen,1)=25,'Not all normal cards eligible';
  for c in select code,special_weight from aamix_private.reward_catalog where code in ('0105','0103','0115','0119') loop assert c.special_weight=5; end loop;
  for c in select code,special_weight from aamix_private.reward_catalog where code in ('0134','0128','0125','0131','0130') loop assert c.special_weight=16; end loop;
  for c in select code from aamix_private.reward_catalog where code in ('0105','0103','0115','0119') loop assert (histogram->>c.code)::integer between 75 and 225,'Named special frequency outside broad 1.5% tolerance'; end loop;
  for c in select code from aamix_private.reward_catalog where code in ('0134','0128','0125','0131','0130') loop assert (histogram->>c.code)::integer between 355 and 605,'Other special frequency outside broad 4.8% tolerance'; end loop;
  for c in select d.cards,t.cards as expected from public.aamix_owned_decks d join aamix_private.base_decks t on t.id=d.deck_id join pg_temp.aamix_reward_qa_users q on q.uid=d.user_id where d.deck_id='maago' loop
    assert c.cards=c.expected,'Exact Maagover template not saved';
  end loop;
  for c in select p.oid::regprocedure as signature,p.prosecdef,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='public' and p.proname like 'aamix_%') or n.nspname='aamix_private' loop
    assert not has_function_privilege('anon',c.signature,'execute'),'Anon function access';
    if c.nspname='public' then assert not c.prosecdef,'Public definer API'; end if;
  end loop;
  assert not has_function_privilege('authenticated','aamix_private.draw_pack()','execute');
  assert not has_function_privilege('authenticated','aamix_private.lock_rewards()','execute');
  assert not has_table_privilege('authenticated','aamix_private.reward_catalog','select');
  insert into pg_temp.aamix_reward_qa_summary values(histogram,special_count,rare_count);
end $$;
select 'PASS: profiles, exact40/15Maagover, starter separation, daily victory/defeat, retries, ordered packs, crash resume, UUID isolation, denied writes, atomic failure, auth guards, 10000 draws; all fixtures rolled back' as validation,
       10000 as sampled_packs,special_count,rare_count,histogram as slot5_histogram from pg_temp.aamix_reward_qa_summary;
rollback;
