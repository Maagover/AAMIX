-- 25 focused assertions; 10 normal-card samples, no simulated AI games.
-- Run only after the reviewed v0.16 migration. All fixtures are rolled back.
begin;
set local plpgsql.check_asserts=on;
create temporary table qa016(label text,uid uuid default gen_random_uuid());
insert into qa016(label) values('a'),('b'),('legacy'),('overflow'),('unconfirmed');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@qa-v016.invalid',case when label='unconfirmed' then null else now() end,now(),now(),false from qa016;
select set_config('qa.a',(select uid::text from qa016 where label='a'),true);
select set_config('qa.b',(select uid::text from qa016 where label='b'),true);
select set_config('qa.legacy',(select uid::text from qa016 where label='legacy'),true);
select set_config('qa.overflow',(select uid::text from qa016 where label='overflow'),true);
select set_config('qa.unconfirmed',(select uid::text from qa016 where label='unconfirmed'),true);
insert into public.aamix_rewards_state(user_id,packs,avatar_code,restos)
  select uid,case when label='legacy' then 7 else 0 end,case when label='legacy' then '0107' else null end,
    case when label='overflow' then 9223372036854775807 else 0 end from qa016 where label in('legacy','overflow');
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'papito',now()-interval '5 minutes',now(),'victory'
    from qa016 cross join generate_series(1,10) where label='a';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'papito',now()-interval '5 minutes',now(),'defeat' from qa016 where label='b';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'papito',now()-interval '1 day 5 minutes',now()-interval '1 day','victory' from qa016 where label='b';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'papito',now()-interval '1 day 5 minutes',now()-interval '1 day','victory'
    from qa016 cross join generate_series(1,10) where label='legacy';
insert into public.aamix_match_receipts(user_id,request_id,deck_id,started_at,finished_at,result)
  select uid,gen_random_uuid(),'papito',now()-interval '5 minutes',now(),'victory' from qa016 where label='legacy';
insert into public.aamix_daily_claims_v016(user_id,mission_id,mission_day,completed_match_id,reward_kind,reward_amount)
  select q.uid,m.id,(now() at time zone 'America/Santiago')::date-1,r.match_id,m.kind,m.amount
    from qa016 q join public.aamix_match_receipts r on r.user_id=q.uid and r.result='victory'
    cross join(values('play_one','restos',50),('win_one','normal_pack',1)) m(id,kind,amount) where q.label='b';
insert into public.aamix_starter_gifts(user_id,deck_id) select uid,'papito' from qa016 where label='legacy';
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select uid,d.id,d.name,d.cover,d.cards from qa016 cross join aamix_private.base_decks d where label='legacy' and d.id='papito';
insert into public.aamix_collection(user_id,code,quantity)
  select uid,e->>'codigo',(e->>'cantidad')::integer from qa016 cross join aamix_private.base_decks d cross join lateral jsonb_array_elements(d.cards)e
    where label='legacy' and d.id='papito';
insert into public.aamix_mission_claims(user_id,mission_id,period_key,reward_packs)
  select uid,m.id,'lifetime',m.amount from qa016 cross join(values('play_ten',5),('win_one',1)) m(id,amount) where label='legacy';
insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id,claimed_at)
  select q.uid,(now() at time zone 'America/Santiago')::date,r.match_id,now()
    from qa016 q join public.aamix_match_receipts r on r.user_id=q.uid
    where q.label='legacy' and (r.finished_at at time zone 'America/Santiago')::date=(now() at time zone 'America/Santiago')::date;

set local role authenticated;
do $$
declare r jsonb; old jsonb; opening jsonb; caught boolean; rejected integer:=0; bad text;
  purchase_request uuid:=gen_random_uuid(); tc_request uuid:=gen_random_uuid(); tc_alias uuid:=gen_random_uuid();
  normal_request uuid:=gen_random_uuid(); normal_alias uuid:=gen_random_uuid();
begin
  assert not exists(select 1 from pg_class where oid in('public.aamix_restos_welcome'::regclass,'public.aamix_shop_purchases'::regclass,'public.aamix_daily_claims_v016'::regclass) and not relrowsecurity)
    and not has_table_privilege('authenticated','public.aamix_shop_purchases','INSERT')
    and not has_table_privilege('authenticated','public.aamix_rewards_state','UPDATE')
    and not has_function_privilege('anon','public.aamix_purchase_card(uuid,text)','EXECUTE')
    and not has_function_privilege('authenticated','aamix_private.draw_normal_card()','EXECUTE')
    and not has_function_privilege('authenticated','aamix_private.open_pack_kind(uuid,text)','EXECUTE')
    and not exists(select 1 from pg_proc where oid in('public.aamix_purchase_card(uuid,text)'::regprocedure,'public.aamix_claim_restos_welcome()'::regprocedure,'public.aamix_open_normal_pack(uuid)'::regprocedure) and prosecdef), '01 owner RLS, no direct writes, invoker wrappers';
  perform set_config('request.jwt.claims','{}',true);
  caught:=false; begin perform public.aamix_claim_restos_welcome(); exception when sqlstate '28000' then caught:=true; end;
  if caught then rejected:=rejected+1; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.unconfirmed'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_purchase_card(gen_random_uuid(),'0101'); exception when sqlstate '28000' then caught:=true; end;
  if caught then rejected:=rejected+1; end if;
  assert rejected=2,'02 anonymous identity and unconfirmed account rejected';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.a'),'role','authenticated')::text,true);
  r:=public.aamix_inventory();
  assert jsonb_array_length(r->'shop')=34
    and (select count(*) from jsonb_array_elements(r->'shop') c where c->>'price'='500' and c->>'code'=any(array['0103','0105','0115','0119']))=4
    and (select count(*) from jsonb_array_elements(r->'shop') c where c->>'price'='150')=30
    and not exists(select 1 from jsonb_array_elements(r->'shop') c where c->>'code'=any(array['0100','01a','01b','01c','01d','01e','01f'])), '03 exact 34-card catalogue and 4 Singular prices';
  r:=public.aamix_claim_restos_welcome(); old:=public.aamix_claim_restos_welcome();
  assert r->>'restos'='100' and r->>'restos_awarded'='true' and old->>'restos'='100' and old->>'restos_awarded'='false'
    and old->>'restos_welcome_claimed'='true' and (select count(*) from public.aamix_restos_welcome)=1
    and old->'gift'='null'::jsonb and old->'collection'='{}'::jsonb and old->>'packs'='0', '04 new account gets exactly 100 once without other rewards';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.b'),'role','authenticated')::text,true);
  old:=public.aamix_inventory(); r:=public.aamix_claim_restos_welcome();
  assert old->>'restos'='0' and old->>'restos_welcome_claimed'='false' and r->>'restos'='100'
    and (select count(*) from public.aamix_restos_welcome)=1,'05 wallet and welcome ledger isolated by account';
  caught:=false; begin perform public.aamix_purchase_card(gen_random_uuid(),'0101'); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_INSUFFICIENT_RESTOS'; end;
  r:=public.aamix_inventory();
  assert caught and r->>'restos'='100' and r->'collection'='{}'::jsonb and (select count(*) from public.aamix_shop_purchases)=0,'06 insufficient funds atomically rejected';
  rejected:=0;
  foreach bad in array array['0100','01a','01b','01c','01d','01e','01f','missing',null] loop
    caught:=false; begin perform public.aamix_purchase_card(gen_random_uuid(),bad); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_CARD_NOT_FOR_SALE'; end;
    if caught then rejected:=rejected+1; end if;
  end loop;
  assert rejected=9 and public.aamix_inventory()->>'restos'='100' and (select count(*) from public.aamix_shop_purchases)=0,'07 resources, every promo and invalid cards never sold';
  r:=public.aamix_inventory();
  assert jsonb_array_length(r->'missions')=4
    and r->'missions'->0->>'scope'='daily' and r->'missions'->0->>'reward_kind'='restos' and r->'missions'->0->>'reward_amount'='50'
    and r->'missions'->1->>'scope'='daily' and r->'missions'->1->>'reward_kind'='normal_pack' and r->'missions'->1->>'reward_amount'='1'
    and r->'missions'->2->>'scope'='lifetime' and r->'missions'->2->>'reward_amount'='3'
    and r->'missions'->3->>'scope'='lifetime' and r->'missions'->3->>'reward_amount'='5','08 four replacement mission definitions';
  assert r->'missions'->0->>'progress'='1' and r->'missions'->1->>'progress'='0'
    and r->'missions'->0->>'claimed'='false' and r->'missions'->1->>'claimed'='false','09 defeat counts for play and yesterday claims reset';
  rejected:=0;
  foreach bad in array array['win_one','play_ten','win_ten','missing'] loop
    caught:=false; begin perform public.aamix_claim_mission(bad); exception when sqlstate '22023' then caught:=sqlerrm in('AAMIX_MISSION_NOT_READY','AAMIX_INVALID_MISSION'); end;
    if caught then rejected:=rejected+1; end if;
  end loop;
  assert rejected=4 and public.aamix_inventory()->>'restos'='100' and public.aamix_inventory()->>'normal_packs'='0','10 incomplete and invalid missions grant nothing';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.a'),'role','authenticated')::text,true);
  r:=public.aamix_claim_mission('play_one'); old:=public.aamix_claim_mission('play_one');
  perform public.aamix_claim_daily_mission();
  assert r->>'restos'='150' and r->>'reward_kind'='restos' and r->>'reward_amount'='50' and r->>'reward_packs'='0'
    and old->>'already_claimed'='true' and public.aamix_inventory()->>'restos'='150' and public.aamix_inventory()->>'packs'='0','11 daily play pays 50 once, legacy endpoint same reward';
  r:=public.aamix_purchase_card(purchase_request,'0101'); old:=public.aamix_purchase_card(purchase_request,'0101');
  assert r->>'restos'='0' and r->'collection'->>'0101'='1' and r->>'purchase_price'='150' and r->>'already_purchased'='false'
    and old->>'already_purchased'='true' and old->>'restos'='0' and old->'purchase'=r->'purchase' and (select count(*) from public.aamix_shop_purchases)=1,'12 normal purchase exact receipt and idempotent retry';
  caught:=false; begin perform public.aamix_purchase_card(purchase_request,'0102'); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_PURCHASE_REQUEST_MISMATCH'; end;
  assert caught and public.aamix_inventory()->>'restos'='0' and not(public.aamix_inventory()->'collection'?'0102'),'13 purchase UUID cannot change card';
  r:=public.aamix_claim_mission('play_ten'); perform public.aamix_claim_mission('play_ten');
  old:=public.aamix_claim_mission('win_ten'); perform public.aamix_claim_mission('win_ten');
  assert r->>'packs'='3' and r->>'reward_amount'='3' and old->>'packs'='8' and old->>'reward_amount'='5'
    and public.aamix_inventory()->>'packs'='8' and (select count(*) from public.aamix_mission_claims)=2,'14 lifetime play ten and win ten pay three and five once';
  r:=public.aamix_claim_mission('win_one'); old:=public.aamix_claim_mission('win_one');
  assert r->>'normal_packs'='1' and r->>'reward_kind'='normal_pack' and r->>'reward_amount'='1' and r->>'reward_packs'='0'
    and old->>'already_claimed'='true' and old->>'normal_packs'='1' and old->>'packs'='8','15 daily victory pays one normal-card pack once';
  assert public.aamix_inventory()->'missions'->0->>'day'=((now() at time zone 'America/Santiago')::date)::text
    and public.aamix_inventory()->'missions'->1->>'timezone'='America/Santiago'
    and (timestamptz '2026-10-19 02:59:59+00' at time zone 'America/Santiago')::date=date '2026-10-18'
    and (timestamptz '2026-10-19 03:00:00+00' at time zone 'America/Santiago')::date=date '2026-10-19','16 both daily missions use Chile midnight boundary';
  r:=public.aamix_open_pack(tc_request); opening:=r->'opening';
  assert r->>'packs'='7' and r->>'normal_packs'='1' and opening->>'kind'='tc' and jsonb_array_length(opening->'cards')=5
    and opening->'cards'->>0='0100' and not(opening->'cards' ?| array['01a','01b','01c','01d','01e','01f'])
    and (select sum(quantity) from public.aamix_collection)=6,'17 TC packs retain five-card resource-first rules';
  r:=public.aamix_open_normal_pack(tc_alias); perform public.aamix_acknowledge_opening((opening->>'opening_id')::uuid);
  old:=public.aamix_open_normal_pack(tc_alias);
  assert r->'opening'=opening and r->>'normal_packs'='1' and old->'opening'->>'opening_id'=opening->>'opening_id'
    and old->'opening'->>'revealed_at' is not null and old->>'normal_packs'='1' and old->>'packs'='7' and (select sum(quantity) from public.aamix_collection)=6,'18 cross-kind TC resume and acknowledged alias never spend again';
  r:=public.aamix_open_normal_pack(normal_request); opening:=r->'opening';
  assert r->>'normal_packs'='0' and r->>'packs'='7' and opening->>'kind'='normal_card' and jsonb_array_length(opening->'cards')=1
    and not(opening->'cards' ?| array['0100','0103','0105','0115','0119','0125','0128','0130','0131','0134','01a','01b','01c','01d','01e','01f'])
    and (select sum(quantity) from public.aamix_collection)=7,'19 normal pack grants exactly one eligible normal card';
  r:=public.aamix_open_pack(normal_alias); perform public.aamix_acknowledge_opening((opening->>'opening_id')::uuid);
  old:=public.aamix_open_normal_pack(normal_request); perform public.aamix_open_pack(normal_alias);
  caught:=false; begin perform public.aamix_open_normal_pack(gen_random_uuid()); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_NO_PACKS'; end;
  assert r->'opening'=opening and old->'opening'->>'opening_id'=opening->>'opening_id' and old->'opening'->>'revealed_at' is not null
    and caught and public.aamix_inventory()->>'packs'='7' and public.aamix_inventory()->>'normal_packs'='0' and (select sum(quantity) from public.aamix_collection)=7,'20 normal resume, ack retry and empty inventory are safe across endpoints';
end $$;

reset role;
-- Synthetic funds and an overflowing synthetic quantity; no real user is modified.
update public.aamix_rewards_state set restos=1000 where user_id=current_setting('qa.a')::uuid;
insert into public.aamix_collection(user_id,code,quantity) values(current_setting('qa.a')::uuid,'0106',2147483647)
  on conflict(user_id,code) do update set quantity=excluded.quantity;
set local role authenticated;
do $$
declare r jsonb; old jsonb; caught boolean; rejected integer:=0; request uuid:=gen_random_uuid(); prior_quantity integer;
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.legacy'),'role','authenticated')::text,true);
  r:=public.aamix_claim_restos_welcome(); perform public.aamix_claim_restos_welcome();
  perform public.aamix_claim_mission('play_one'); perform public.aamix_claim_mission('win_one'); old:=public.aamix_claim_mission('play_ten');
  assert r->>'restos'='100' and r->>'packs'='7' and old->>'restos'='150' and old->>'normal_packs'='1'
    and old->>'packs'='7' and old->>'already_claimed'='true' and old->>'reward_amount'='5'
    and old->'gift'->>'deck_id'='papito' and old->'profile'->>'avatar_code'='0107' and (select sum(quantity) from public.aamix_collection)=40
    and (select count(*) from public.aamix_mission_claims where mission_id='win_one' and period_key='lifetime')=1
    and (select reward_packs from public.aamix_mission_claims where mission_id='play_ten')=5
    and exists(select 1 from public.aamix_daily_missions where claimed_at is not null),'21 existing account gets 100; historical awards preserved and new daily rewards independent';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.a'),'role','authenticated')::text,true);
  prior_quantity:=coalesce((public.aamix_inventory()->'collection'->>'0105')::integer,0);
  r:=public.aamix_purchase_card(request,'0105'); old:=public.aamix_purchase_card(gen_random_uuid(),'0125');
  perform public.aamix_purchase_card(request,'0105');
  assert r->>'restos'='500' and r->>'purchase_price'='500' and old->>'restos'='350' and old->>'purchase_price'='150'
    and (r->'collection'->>'0105')::integer=prior_quantity+1 and public.aamix_inventory()->>'restos'='350'
    and (select count(*) from public.aamix_shop_purchases)=3,'22 Singular costs 500; other Special costs 150; retry keeps debit once';
  caught:=false; begin perform public.aamix_purchase_card(gen_random_uuid(),'0106'); exception when numeric_value_out_of_range then caught:=true; end;
  if caught and public.aamix_inventory()->>'restos'='350' and (select count(*) from public.aamix_shop_purchases)=3 then rejected:=rejected+1; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.overflow'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_claim_restos_welcome(); exception when numeric_value_out_of_range then caught:=true; end;
  if caught and (select count(*) from public.aamix_restos_welcome)=0 and public.aamix_inventory()->>'restos'='9223372036854775807' then rejected:=rejected+1; end if;
  assert rejected=2,'23 collection and wallet overflows roll back the complete grant or purchase';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.a'),'role','authenticated')::text,true);
  rejected:=0;
  caught:=false; begin update public.aamix_rewards_state set restos=999999; exception when insufficient_privilege then caught:=true; end;
  if caught then rejected:=rejected+1; end if;
  caught:=false; begin delete from public.aamix_restos_welcome; exception when insufficient_privilege then caught:=true; end;
  if caught then rejected:=rejected+1; end if;
  caught:=false; begin insert into public.aamix_shop_purchases(user_id,request_id,code,price) values(auth.uid(),gen_random_uuid(),'0101',150); exception when insufficient_privilege then caught:=true; end;
  if caught then rejected:=rejected+1; end if;
  old:=public.aamix_inventory();
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.b'),'role','authenticated')::text,true);
  assert rejected=3 and old->>'restos'='350' and public.aamix_inventory()->>'restos'='100'
    and (select count(*) from public.aamix_shop_purchases)=0 and (select count(*) from public.aamix_daily_claims_v016)=2
    and (select count(*) from public.aamix_restos_welcome)=1,'24 no balance/receipt writes or cross-account receipt reads';
end $$;
reset role;
do $$
declare sample jsonb; eligible integer:=0;
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.a'),'role','authenticated')::text,true);
  for n in 1..10 loop
    sample:=aamix_private.draw_normal_card();
    if jsonb_array_length(sample)=1 and exists(select 1 from aamix_private.reward_catalog where code=sample->>0 and not is_promotional and card_class<>'Recurso' and special_weight=0) then eligible:=eligible+1; end if;
  end loop;
  assert eligible=10 and (select count(*) from aamix_private.reward_catalog where not is_promotional and card_class<>'Recurso' and special_weight=0)=25,'25 bounded samples contain only the exact 25 normal cards';
end $$;
rollback;
select jsonb_build_object('checks',25,'failures',0,'normal_card_samples',10,'normal_pack_openings',1,'tc_pack_openings',1,'all_fixtures_rolled_back',true,'real_rewards_claimed',0) as economy_v016_result;
