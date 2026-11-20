-- AAMIX 1.2 focused design-entitlement verification; synthetic users only and rollback.
begin;
set local plpgsql.check_asserts=on;
create temporary table qa120_users(label text primary key,uid uuid default gen_random_uuid());
insert into qa120_users(label) values('a'),('b');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@qa-v120.invalid',now(),now(),now(),false from qa120_users;
select set_config('qa120.a',(select uid::text from qa120_users where label='a'),true);
select set_config('qa120.b',(select uid::text from qa120_users where label='b'),true);
insert into public.aamix_collection(user_id,code,quantity)
  select uid,'0100',40 from qa120_users where label='a';
set local role authenticated;
do $$
declare initial jsonb; r jsonb; replay jsonb; saved jsonb; cover text; gift text; locked boolean;
  req uuid:=gen_random_uuid(); custom_id text;
begin
  assert not has_table_privilege('authenticated','public.aamix_code_redemptions','INSERT')
    and not has_column_privilege('authenticated','public.aamix_code_redemptions','deck_design','UPDATE')
    and not has_function_privilege('anon','aamix_private.deck_designs_inventory()','EXECUTE')
    and not (select prosecdef from pg_proc where oid='public.aamix_inventory()'::regprocedure),
    '01 design ledger remains server-only and inventory invoker';
  perform set_config('request.jwt.claims','{}',true);
  locked:=false; begin perform aamix_private.deck_designs_inventory(); exception when sqlstate '28000' then locked:=true; end;
  assert locked,'02 anonymous entitlement request rejected';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa120.a'),'role','authenticated')::text,true);
  initial:=public.aamix_inventory();
  assert initial->'available_custom_covers'='["custom_transmision","custom_restos"]'::jsonb
    and initial->'unlocked_deck_designs'='[]'::jsonb,'03 defaults free with no earned covers';
  foreach cover in array array['custom_tsuki_akira','custom_chanchuus','custom_viborin'] loop
    locked:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Bloqueado',cover,'[]',true,0); exception when sqlstate '22023' then locked:=sqlerrm='AAMIX_DECK_COVER_LOCKED'; end;
    assert locked,'04 unclaimed earned cover rejected even for drafts';
  end loop;
  locked:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Base ajena','0105','[]',true,0); exception when sqlstate '22023' then locked:=sqlerrm='AAMIX_INVALID_DECK'; end;
  assert locked,'05 fixed base covers never enter custom cover enum';
  for gift,cover in select * from (values('SI2MAZO','custom_tsuki_akira'),('CHANCHUMAZO','custom_chanchuus'),('VIBMAZO','custom_viborin')) pairs(gift,cover) loop
    r:=public.aamix_redeem_code('  '||lower(gift)||'  ');
    assert r->>'already_redeemed'='false' and r->>'reward_cover'=cover and r->>'reward_design'=cover
      and r->'reward_cards'='[]'::jsonb and r->>'reward_packs'='0' and r->>'reward_restos'='0' and r->>'reward_normal_packs'='0'
      and r->'collection'=initial->'collection' and r->'decks'=initial->'decks'
      and r->>'restos'=initial->>'restos' and r->>'packs'=initial->>'packs' and r->>'normal_packs'=initial->>'normal_packs'
      and r->>'restos_welcome_claimed'='false','06 exact cosmetic-only normalized claim, no welcome currency';
    replay:=public.aamix_redeem_code(gift);
    assert replay->>'already_redeemed'='true' and replay->>'reward_cover'=cover
      and replay->'unlocked_deck_designs'=r->'unlocked_deck_designs','07 cosmetic retry idempotent';
    r:=public.aamix_save_custom_deck(gen_random_uuid(),'','Diseño ganado',cover,'[]',true,0);
    assert r->'saved_deck'->>'portada'=cover and r->'saved_deck'->>'revision'='1','08 earned designs available without pictured-card ownership';
  end loop;
  r:=public.aamix_inventory();
  assert r->'available_custom_covers'='["custom_transmision","custom_restos","custom_tsuki_akira","custom_chanchuus","custom_viborin"]'::jsonb
    and r->'unlocked_deck_designs'='["custom_tsuki_akira","custom_chanchuus","custom_viborin"]'::jsonb
    and (select count(*) from public.aamix_code_redemptions where deck_design is not null)=3,'09 reload stable ordered entitlements and one receipt per code';
  r:=public.aamix_save_custom_deck(req,'','Final cosmético','custom_chanchuus','[{"codigo":"0100","cantidad":40}]',false,0);
  saved:=r->'saved_deck'; custom_id:=saved->>'id';
  replay:=public.aamix_save_custom_deck(req,'','Final cosmético','custom_chanchuus','[{"codigo":"0100","cantidad":40}]',false,0);
  assert replay->'saved_deck'=saved and public.aamix_begin_match(gen_random_uuid(),custom_id)->'match_deck'=saved,'10 final save/retry and gameplay snapshot with earned cover';
  r:=public.aamix_save_custom_deck(gen_random_uuid(),custom_id,'Final editado','custom_viborin','[{"codigo":"0100","cantidad":40}]',false,1);
  assert r->'saved_deck'->>'revision'='2' and r->'saved_deck'->>'portada'='custom_viborin','11 earned cover edit preserves optimistic revision';
  r:=public.aamix_save_custom_deck(gen_random_uuid(),'','Cliente1.1','custom_restos','[]',true,0);
  assert r->'saved_deck'->>'portada'='custom_restos' and r->'decks'=initial->'decks','12 default cover and old inventory contract unchanged';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa120.b'),'role','authenticated')::text,true);
  r:=public.aamix_inventory();
  assert r->'unlocked_deck_designs'='[]'::jsonb and (select count(*) from public.aamix_code_redemptions)=0,'13 UUID entitlement and ledger RLS isolation';
  locked:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','No prestado','custom_chanchuus','[]',true,0); exception when sqlstate '22023' then locked:=sqlerrm='AAMIX_DECK_COVER_LOCKED'; end;
  assert locked,'14 another owner cannot borrow design';
  r:=public.aamix_redeem_code('AAMIX50'); replay:=public.aamix_redeem_code('AAMIX50');
  assert r->>'restos'='150' and replay->>'restos'='150' and replay->>'already_redeemed'='true'
    and r->'reward_cover'='null'::jsonb and r->'unlocked_deck_designs'='[]'::jsonb,'15 existing currency code/welcome/idempotence preserved';
end $$;
reset role;
-- Metadata changes are transaction-only. A claimed design is a stable ledger snapshot.
update aamix_private.gift_code_rewards set deck_design='custom_viborin' where gift_code='SI2MAZO';
delete from aamix_private.gift_code_rewards where gift_code='CHANCHUMAZO';
set local role authenticated;
do $$
declare r jsonb; replay jsonb;
begin
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa120.a'),'role','authenticated')::text,true);
  r:=public.aamix_redeem_code('SI2MAZO'); replay:=public.aamix_redeem_code('CHANCHUMAZO');
  assert r->>'reward_cover'='custom_tsuki_akira' and replay->>'reward_cover'='custom_chanchuus'
    and r->>'already_redeemed'='true' and replay->>'already_redeemed'='true'
    and r->>'restos'='0' and replay->>'restos'='0','16 changed/removed metadata cannot retarget or repeat earned reward';
  r:=public.aamix_save_custom_deck(gen_random_uuid(),'','Persistente','custom_chanchuus','[]',true,0);
  assert r->'saved_deck'->>'portada'='custom_chanchuus'
    and r->'unlocked_deck_designs'='["custom_tsuki_akira","custom_chanchuus","custom_viborin"]'::jsonb,'17 snapshot entitlements persist without active code definitions';
end $$;
reset role;
select jsonb_build_object('status','passed','groups',17,'synthetic_accounts',2,'random_draws',0,'writes','transaction rolls back next') as verification;
rollback;

