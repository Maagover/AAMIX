-- 12 focused assertions, no random draws or simulated games. All fixtures roll back.
begin;
set local plpgsql.check_asserts=on;
create temporary table qa017_gifts(label text,uid uuid default gen_random_uuid());
insert into qa017_gifts(label) values('a'),('b'),('invalid'),('overflow'),('unconfirmed');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@qa-gifts-v017.invalid',case when label='unconfirmed' then null else now() end,now(),now(),false from qa017_gifts;
select set_config('qa.gift_a',(select uid::text from qa017_gifts where label='a'),true);
select set_config('qa.gift_b',(select uid::text from qa017_gifts where label='b'),true);
select set_config('qa.gift_invalid',(select uid::text from qa017_gifts where label='invalid'),true);
select set_config('qa.gift_overflow',(select uid::text from qa017_gifts where label='overflow'),true);
select set_config('qa.gift_unconfirmed',(select uid::text from qa017_gifts where label='unconfirmed'),true);
insert into public.aamix_rewards_state(user_id,restos,packs,normal_packs)
  select uid,9223372036854775807,0,0 from qa017_gifts where label='overflow';
insert into public.aamix_restos_welcome(user_id) select uid from qa017_gifts where label='overflow';
do $$
declare rejected integer:=0;
begin
  assert (select relrowsecurity from pg_class where oid='aamix_private.gift_code_rewards'::regclass)
    and not has_table_privilege('authenticated','aamix_private.gift_code_rewards','SELECT')
    and not has_table_privilege('authenticated','public.aamix_code_redemptions','INSERT')
    and not has_function_privilege('anon','public.aamix_redeem_code(text)','EXECUTE')
    and has_function_privilege('authenticated','public.aamix_redeem_code(text)','EXECUTE')
    and not (select prosecdef from pg_proc where oid='public.aamix_redeem_code(text)'::regprocedure),
    '01 private configuration, owner ledger and authenticated-only invoker preserved';
  assert (select count(*) from aamix_private.gift_code_rewards)=12
    and (select count(*) from aamix_private.gift_code_rewards where gift_code in('M4Z0M44G0','P3RI','B1G0T3S','SI2TYA','CHANCHULINES','TORNEOAAMIX1','AAMIXTC','M4Z0G1R4') and restos=0 and normal_packs=0)=8
    and (select count(*) from aamix_private.gift_code_rewards c join (values
      ('AAMIX50',0,50,0),('AAMIX100',0,100,0),('AAMIX1000',0,1000,0),('AAMIXNAVIDAD',1,50,1)
      ) v(code,packs,restos,normal_packs) on c.gift_code=v.code and c.packs=v.packs and c.restos=v.restos and c.normal_packs=v.normal_packs
      where c.deck_id is null and c.cards is null)=4,
    '02 all eight old definitions preserved and four new exact wallet definitions';
  begin insert into aamix_private.gift_code_rewards(gift_code,reward_name) values('QA_EMPTY','invalid'); exception when check_violation then rejected:=rejected+1; end;
  begin insert into aamix_private.gift_code_rewards(gift_code,reward_name,deck_id,restos) values('QA_DECK_CURRENCY','invalid','maago',50); exception when check_violation then rejected:=rejected+1; end;
  begin insert into aamix_private.gift_code_rewards(gift_code,reward_name,cards,normal_packs) values('QA_CARDS_PACK','invalid','[{"codigo":"01a","cantidad":1}]',1); exception when check_violation then rejected:=rejected+1; end;
  begin insert into aamix_private.gift_code_rewards(gift_code,reward_name,restos) values('QA_NEGATIVE','invalid',-50); exception when check_violation then rejected:=rejected+1; end;
  assert rejected=4,'03 empty, negative and mixed legacy card/deck configuration rejected';
end $$;
set local role authenticated;
do $$
declare r jsonb; old jsonb; caught boolean; rejected integer:=0; before_state jsonb;
begin
  perform set_config('request.jwt.claims','{}',true);
  begin perform public.aamix_redeem_code('AAMIX50'); exception when sqlstate '28000' then rejected:=rejected+1; end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.gift_unconfirmed'),'role','authenticated')::text,true);
  begin perform public.aamix_redeem_code('AAMIX50'); exception when sqlstate '28000' then rejected:=rejected+1; end;
  assert rejected=2,'04 missing identity and unconfirmed account cannot redeem';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.gift_a'),'role','authenticated')::text,true);
  r:=public.aamix_redeem_code('  aamix50  ');
  assert r->>'restos'='150' and r->>'packs'='0' and r->>'normal_packs'='0' and r->>'reward_restos'='50'
    and r->>'reward_packs'='0' and r->>'reward_normal_packs'='0' and r->>'redeemed_code'='AAMIX50'
    and r->>'already_redeemed'='false' and r->>'restos_welcome_claimed'='true'
    and r->'gift'='null'::jsonb and r->'collection'='{}'::jsonb and r->'decks'='[]'::jsonb
    and (select count(*) from public.aamix_restos_welcome)=1 and (select count(*) from public.aamix_welcome_packs)=0,
    '05 normalized first currency code awards exactly 100 registration plus 50, no implicit starter or pack';
  old:=public.aamix_redeem_code('AAMIX50'); perform public.aamix_redeem_code('aamix50');
  assert old->>'already_redeemed'='true' and old->>'restos'='150' and old->>'reward_restos'='50'
    and (select count(*) from public.aamix_code_redemptions)=1 and public.aamix_inventory()->>'restos'='150',
    '06 normalized same-code retries never duplicate currency';
  r:=public.aamix_redeem_code('AAMIX100'); old:=public.aamix_redeem_code('AAMIX1000');
  perform public.aamix_redeem_code('AAMIX100'); perform public.aamix_redeem_code('AAMIX1000');
  assert r->>'restos'='250' and r->>'reward_restos'='100' and old->>'restos'='1250' and old->>'reward_restos'='1000'
    and public.aamix_inventory()->>'restos'='1250' and (select count(*) from public.aamix_code_redemptions)=3,
    '07 100 and 1000 codes award exact amounts once';
  r:=public.aamix_redeem_code('AAMIXNAVIDAD'); old:=public.aamix_redeem_code('AAMIXNAVIDAD');
  assert r->>'restos'='1300' and r->>'packs'='1' and r->>'normal_packs'='1'
    and r->>'reward_restos'='50' and r->>'reward_packs'='1' and r->>'reward_normal_packs'='1'
    and r->'reward_cards'='[]'::jsonb and r->'reward_deck_id'='null'::jsonb
    and old->>'already_redeemed'='true' and old->>'restos'='1300' and old->>'packs'='1' and old->>'normal_packs'='1'
    and (select count(*) from public.aamix_code_redemptions)=4,
    '08 Christmas gift grants its three rewards atomically and retries retain exact reply';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.gift_b'),'role','authenticated')::text,true);
  r:=public.aamix_redeem_code('AAMIX50');
  assert r->>'restos'='150' and (select count(*) from public.aamix_code_redemptions)=1
    and r->'redeemed_codes'='["AAMIX50"]'::jsonb and r->>'packs'='0' and r->>'normal_packs'='0',
    '09 each account independently redeems the same code with owner-only ledger visibility';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.gift_a'),'role','authenticated')::text,true);
  perform public.aamix_redeem_code('P3RI'); perform public.aamix_redeem_code('AAMIXTC');
  perform public.aamix_redeem_code('M4Z0M44G0'); r:=public.aamix_redeem_code('M4Z0G1R4');
  perform public.aamix_redeem_code('P3RI'); perform public.aamix_redeem_code('M4Z0G1R4');
  assert r->>'restos'='1300' and r->>'packs'='2' and r->>'normal_packs'='1' and r->>'reward_restos'='0'
    and r->>'reward_normal_packs'='0' and r->>'reward_deck_id'='girabl' and jsonb_array_length(r->'decks')=2
    and (select sum(quantity) from public.aamix_collection)=83 and r->'gift'='null'::jsonb
    and (select count(*) from public.aamix_code_redemptions)=8 and public.aamix_inventory()->>'restos'='1300',
    '10 promotional cards, TC pack and both legacy decks retain exact awards and retry behavior';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.gift_invalid'),'role','authenticated')::text,true);
  before_state:=public.aamix_inventory(); caught:=false;
  begin perform public.aamix_redeem_code('NOT_A_GIFT'); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_INVALID_CODE'; end;
  assert caught and public.aamix_inventory()=before_state and (select count(*) from public.aamix_restos_welcome)=0
    and (select count(*) from public.aamix_code_redemptions)=0,'11 invalid code leaves every account reward unchanged';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa.gift_overflow'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_redeem_code('AAMIXNAVIDAD'); exception when numeric_value_out_of_range then caught:=true; end;
  r:=public.aamix_inventory();
  assert caught and r->>'restos'='9223372036854775807' and r->>'packs'='0' and r->>'normal_packs'='0'
    and (select count(*) from public.aamix_code_redemptions)=0 and r->'collection'='{}'::jsonb,
    '12 overflow rolls back the whole combined gift and its redemption gate';
end $$;
reset role;
rollback;
select jsonb_build_object('checks',12,'failures',0,'all_fixtures_rolled_back',true,'real_rewards_claimed',0) as wallet_gifts_v017_result;
