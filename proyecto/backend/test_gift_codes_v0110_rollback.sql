-- AAMIX0.11.0 integration test: run AFTER aamix_gift_codes_v0110.sql.
-- Synthetic random UUIDs only; ALL account/cards/awards roll back. No emails.
begin;
set local plpgsql.check_asserts=on;
create temporary table aamix_v011_qa_users(label text primary key,uid uuid not null default gen_random_uuid());
insert into aamix_v011_qa_users(label) values('a'),('b'),('unconfirmed'),('anonymous'),('overflow');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@aamix-v011-qa.invalid',case when label='unconfirmed' then null else now() end,now(),now(),label='anonymous'
  from pg_temp.aamix_v011_qa_users;
select set_config('aamix.v011_a',(select uid::text from pg_temp.aamix_v011_qa_users where label='a'),true);
select set_config('aamix.v011_b',(select uid::text from pg_temp.aamix_v011_qa_users where label='b'),true);
select set_config('aamix.v011_unconfirmed',(select uid::text from pg_temp.aamix_v011_qa_users where label='unconfirmed'),true);
select set_config('aamix.v011_anonymous',(select uid::text from pg_temp.aamix_v011_qa_users where label='anonymous'),true);
select set_config('aamix.v011_overflow',(select uid::text from pg_temp.aamix_v011_qa_users where label='overflow'),true);
insert into public.aamix_collection(user_id,code,quantity)
  select uid,'01b',2147483647 from pg_temp.aamix_v011_qa_users where label='overflow';
insert into public.aamix_rewards_state(user_id,packs)
  select uid,7 from pg_temp.aamix_v011_qa_users where label='overflow';

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v011_a'),'role','authenticated')::text,true);
do $$
declare
  codes text[]:=array['P3RI','B1G0T3S','SI2TYA','CHANCHULINES','TORNEOAAMIX1'];
  cards text[]:=array['01a','01b','01c','01d','01e'];
  quantities integer[]:=array[3,3,1,1,1];
  r jsonb; baseline jsonb; original jsonb; reward jsonb; i integer; retry integer; c text;
begin
  baseline:=public.aamix_inventory();
  assert baseline->'collection'='{}'::jsonb and baseline->'decks'='[]'::jsonb;
  assert baseline->'gift'='null'::jsonb and (baseline->>'packs')::integer=0;
  begin perform public.aamix_redeem_code(null); raise exception 'NULL code accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_redeem_code('P3RI0'); raise exception 'Incorrect Peri code accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_redeem_code('01f'); raise exception 'Unconfigured promo accepted'; exception when invalid_parameter_value then null; end;
  begin perform public.aamix_redeem_code('M4Z0M44G0''; select 1; --'); raise exception 'Unknown/injected code accepted'; exception when invalid_parameter_value then null; end;
  assert public.aamix_inventory()=baseline,'Invalid codes changed inventory';
  -- Promos are locked before and after ownership, including the unawarded 01f.
  foreach c in array array['01a','01b','01c','01d','01e','01f'] loop
    begin perform public.aamix_set_avatar(c); raise exception 'Unowned promotional avatar accepted'; exception when invalid_parameter_value then null; end;
  end loop;
  r:=public.aamix_set_avatar('0108');
  assert r->'profile'->>'avatar_code'='0108';
  for i in 1..5 loop
    r:=public.aamix_redeem_code(' '||lower(codes[i])||' ');
    reward:=jsonb_build_array(jsonb_build_object('codigo',cards[i],'cantidad',quantities[i]));
    assert r->>'already_redeemed'='false','First per-UUID redemption already used';
    assert r->>'redeemed_code'=codes[i];
    assert r->'reward_deck_id'='null'::jsonb,'Card code granted a deck';
    assert r->'reward_cards'=reward,'Wrong card or quantity in response';
    assert length(r->>'reward_name')>0;
    assert (r->'collection'->>cards[i])::integer=quantities[i],'Wrong collection quantity';
    assert jsonb_array_length(r->'decks')=0 and (r->>'packs')::integer=0,'Promo code granted deck or pack';
    assert r->'gift'='null'::jsonb and r->'mission'=baseline->'mission','Promo code consumed starter or mission';
    original:=r-'already_redeemed';
    for retry in 1..20 loop
      r:=public.aamix_redeem_code(codes[i]);
      assert r->>'already_redeemed'='true';
      assert r-'already_redeemed'=original,'Retry duplicated or altered promo';
    end loop;
    begin perform public.aamix_set_avatar(cards[i]); raise exception 'Owned promotional avatar accepted'; exception when invalid_parameter_value then null; end;
    assert public.aamix_inventory()->'profile'->>'avatar_code'='0108','Denied avatar changed profile';
  end loop;
  r:=public.aamix_inventory();
  assert r->'collection'='{"01a":3,"01b":3,"01c":1,"01d":1,"01e":1}'::jsonb;
  assert jsonb_array_length(r->'redeemed_codes')=5;
  r:=public.aamix_redeem_code('M4Z0M44G0');
  assert r->>'already_redeemed'='false' and r->>'reward_deck_id'='maago';
  assert r->>'reward_name'='Mazo Maagover';
  assert (select sum((e->>'cantidad')::integer) from jsonb_array_elements(r->'reward_cards') e)=40;
  assert (select (e->>'cantidad')::integer from jsonb_array_elements(r->'reward_cards') e where e->>'codigo'='0100')=15;
  assert jsonb_array_length(r->'decks')=1 and r->'decks'->0->>'id'='maago';
  assert r->'decks'->0->'cartas'=r->'reward_cards','Saved Maagover differs from awarded list';
  assert (r->'collection'->>'0100')::integer=15 and (r->'collection'->>'01c')::integer=2,'Maagover overwrote existing promos';
  assert (select sum(value::integer) from jsonb_each_text(r->'collection'))=49;
  assert (r->>'packs')::integer=0 and r->'gift'='null'::jsonb;
  original:=r-'already_redeemed';
  for retry in 1..20 loop
    r:=public.aamix_redeem_code(' m4z0m44g0 ');
    assert r->>'already_redeemed'='true' and r-'already_redeemed'=original,'Maagover retry duplicated award';
  end loop;
  begin perform public.aamix_claim_starter('maago'); raise exception 'Maagover accepted as starter'; exception when invalid_parameter_value then null; end;
  r:=public.aamix_claim_starter('kajido');
  assert r->>'already_claimed'='false' and jsonb_array_length(r->'decks')=2;
  assert (select sum(value::integer) from jsonb_each_text(r->'collection'))=89;
  -- Remote identity gate and direct write restrictions remain unchanged.
  begin update public.aamix_code_redemptions set gift_code='FAKE'; raise exception 'Direct redemption update'; exception when insufficient_privilege then null; end;
  begin insert into public.aamix_collection(user_id,code,quantity) values(auth.uid(),'01f',999); raise exception 'Direct quantity grant'; exception when insufficient_privilege then null; end;
  begin perform 1 from aamix_private.gift_code_rewards; raise exception 'Private rewards exposed'; exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v011_b'),'role','authenticated')::text,true);
do $$
declare c text; r jsonb;
begin
  r:=public.aamix_inventory();
  assert r->'collection'='{}'::jsonb and (select count(*) from public.aamix_code_redemptions)=0,'Cross-UUID leak';
  foreach c in array array['M4Z0M44G0','P3RI','B1G0T3S','SI2TYA','CHANCHULINES','TORNEOAAMIX1'] loop
    r:=public.aamix_redeem_code(c);
    assert r->>'already_redeemed'='false','Redemption limit incorrectly global';
  end loop;
  assert (select count(*) from public.aamix_code_redemptions)=6;
  assert (select sum(value::integer) from jsonb_each_text(r->'collection'))=49;
  assert (r->'collection'->>'01c')::integer=2 and (r->>'packs')::integer=0;
  assert r->'gift'='null'::jsonb and jsonb_array_length(r->'decks')=1;
end $$;

select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v011_overflow'),'role','authenticated')::text,true);
do $$
declare original jsonb;
begin
  original:=public.aamix_inventory();
  begin perform public.aamix_redeem_code('B1G0T3S'); raise exception 'Expected overflow not raised'; exception when numeric_value_out_of_range then null; end;
  assert public.aamix_inventory()=original,'Failed award committed partial inventory/redemption';
  assert (select count(*) from public.aamix_code_redemptions)=0;
  assert (select packs from public.aamix_rewards_state)=7;
  assert (select count(*) from public.aamix_owned_decks)=0;
  assert (select quantity from public.aamix_collection where code='01b')=2147483647;
end $$;

do $$
declare label text; c text;
begin
  foreach label in array array['unconfirmed','anonymous'] loop
    perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v011_'||label),'role','authenticated')::text,true);
    foreach c in array array['M4Z0M44G0','P3RI','B1G0T3S','SI2TYA','CHANCHULINES','TORNEOAAMIX1'] loop
      begin perform public.aamix_redeem_code(c); raise exception 'Unverified/anonymous code accepted'; exception when invalid_authorization_specification then null; end;
    end loop;
    begin perform public.aamix_set_avatar('0108'); raise exception 'Unverified avatar accepted'; exception when invalid_authorization_specification then null; end;
    assert (select count(*) from public.aamix_code_redemptions)=0;
  end loop;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  begin perform public.aamix_redeem_code('P3RI'); raise exception 'Nonexistent user accepted'; exception when invalid_authorization_specification then null; end;
  perform set_config('request.jwt.claims','{}',true);
  begin perform public.aamix_redeem_code('P3RI'); raise exception 'Missing UUID accepted'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;

-- Existing Maagover redemptions are recognized after the code table is generalized.
insert into public.aamix_code_redemptions(user_id,gift_code)
  select uid,'M4Z0M44G0' from pg_temp.aamix_v011_qa_users where label='overflow';
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v011_overflow'),'role','authenticated')::text,true);
do $$
declare r jsonb;
begin
  r:=public.aamix_redeem_code('M4Z0M44G0');
  assert r->>'already_redeemed'='true';
  assert (select count(*) from public.aamix_owned_decks where user_id=auth.uid())=0,'Legacy redeemed code delivered again';
end $$;

-- Catalogue and pack regression: owning/promotional codes never joins the pack pool.
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('aamix.v011_a'),'role','authenticated')::text,true);
do $$
declare p jsonb; i integer; slot integer; c record;
begin
  assert (select count(*) from aamix_private.gift_code_rewards)=8;
  assert (select count(*) from aamix_private.reward_catalog where not is_promotional)=35;
  assert (select count(*) from aamix_private.reward_catalog where not is_promotional and card_class<>'Recurso' and special_weight=0)=25;
  for i in 1..1000 loop
    p:=aamix_private.draw_pack();
    assert jsonb_array_length(p)=5 and p->>0='0100';
    for slot in 0..4 loop
      assert exists(select 1 from aamix_private.reward_catalog where code=p->>slot and not is_promotional),'Promo entered pack';
      if slot>0 then assert p->>slot<>'0100','Resource outside slot1'; end if;
    end loop;
  end loop;
  for c in select code from aamix_private.reward_catalog where card_class='Aliado' and not is_promotional loop
    assert public.aamix_set_avatar(c.code)->'profile'->>'avatar_code'=c.code,'Eligible avatar rejected';
  end loop;
  assert not has_table_privilege('authenticated','aamix_private.gift_code_rewards','select');
  assert not has_table_privilege('anon','aamix_private.gift_code_rewards','select');
  assert not has_function_privilege('anon','public.aamix_redeem_code(text)','execute');
  assert not has_function_privilege('anon','aamix_private.redeem_code(text)','execute');
  assert not has_function_privilege('anon','public.aamix_set_avatar(text)','execute');
  assert not has_function_privilege('authenticated','aamix_private.draw_pack()','execute');
  assert (select not prosecdef from pg_proc where oid='public.aamix_redeem_code(text)'::regprocedure);
  assert (select not prosecdef from pg_proc where oid='public.aamix_set_avatar(text)'::regprocedure);
end $$;
select 'PASS: five exact promo codes, Maagover40/15 preserved, 20 retries per code, per-UUID isolation, auth/ACL, atomic overflow rollback, no promo avatars even owned, 1000 promo-free packs; ALL fixtures rolled back' as validation;
rollback;
