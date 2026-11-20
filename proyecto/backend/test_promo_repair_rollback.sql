-- AAMIX 0.10.1 administrative repair integration test. EVERYTHING rolls back.
-- Run only after aamix_no_promo_packs.sql and promo_repair_admin.sql.
-- Requires an administrative SQL role. Never signs in as, deletes or awards a real user.
-- The entire fixture uses fresh random UUIDs and @aamix-qa.invalid addresses.
-- Covers legitimate Maagover promo preservation, exact replacement, total quantity,
-- opening/request history, idempotence, client privileges and atomic failure.
begin;
set local plpgsql.check_asserts = on;

do $$
declare
  main_uid uuid := gen_random_uuid();
  missing_uid uuid := gen_random_uuid();
  opening_uid uuid := gen_random_uuid();
  missing_opening_uid uuid := gen_random_uuid();
  first_request uuid := gen_random_uuid();
  alias_request uuid := gen_random_uuid();
  before_cards jsonb := '["0100","0104","01c","0104","0105"]'::jsonb;
  missing_cards jsonb := '["0100","01a","01b","0104","0105"]'::jsonb;
  result jsonb;
  first_repair jsonb;
  second_repair jsonb;
  corrected jsonb;
  baseline_decks jsonb;
  baseline_redemptions jsonb;
  baseline_wallet jsonb;
  baseline_requests jsonb;
  corrected_collection jsonb;
  corrected_opening jsonb;
  corrected_audit jsonb;
  missing_collection jsonb;
  missing_opening jsonb;
  replacement text;
  repeat_index integer;
begin
  assert not has_function_privilege('anon','aamix_private.correct_promo_pack(uuid)','EXECUTE'),
    'Anonymous client can run administrative repair';
  assert not has_function_privilege('authenticated','aamix_private.correct_promo_pack(uuid)','EXECUTE'),
    'Authenticated client can run administrative repair';
  assert not has_table_privilege('anon','aamix_private.pack_promo_corrections','SELECT'),
    'Anonymous client can read private repair audit';
  assert not has_table_privilege('authenticated','aamix_private.pack_promo_corrections','SELECT'),
    'Authenticated client can read private repair audit';

  insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
    values
      (main_uid,main_uid::text||'@aamix-qa.invalid',now(),now(),now(),false),
      (missing_uid,missing_uid::text||'@aamix-qa.invalid',now(),now(),now(),false);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',main_uid::text,'role','authenticated')::text,true);

  -- Obtain the actual historical Maagover through its existing code RPC.
  result := public.aamix_redeem_code('M4Z0M44G0');
  assert result->>'already_redeemed'='false';
  assert (select sum(quantity) from public.aamix_collection where user_id=main_uid)=40,
    'Maagover did not award exactly 40 cards';
  assert (select quantity from public.aamix_collection where user_id=main_uid and code='01c')=1,
    'Fixture must retain the one legitimate Maagover promotional copy';
  assert (select quantity from public.aamix_collection where user_id=main_uid and code='0100')=15,
    'Maagover resource composition changed';

  select jsonb_agg(to_jsonb(d) order by d.deck_id) into baseline_decks
    from public.aamix_owned_decks d where d.user_id=main_uid;
  select jsonb_agg(to_jsonb(r) order by r.gift_code) into baseline_redemptions
    from public.aamix_code_redemptions r where r.user_id=main_uid;
  select to_jsonb(w) into baseline_wallet from public.aamix_rewards_state w where w.user_id=main_uid;

  -- Simulate a truthful already-revealed 0.10.0 pack containing one extra 01c.
  -- Only historical rows may contain promotions after the new pack constraint.
  insert into public.aamix_pack_openings(opening_id,user_id,request_id,cards,opened_at,revealed_at,rules_version)
    values(opening_uid,main_uid,first_request,before_cards,now()-interval '1 hour',now()-interval '30 minutes','0.10.0');
  insert into public.aamix_pack_requests(user_id,request_id,opening_id)
    values(main_uid,first_request,opening_uid),(main_uid,alias_request,opening_uid);
  insert into public.aamix_collection(user_id,code,quantity)
    select main_uid,code,count(*)::integer
      from jsonb_array_elements_text(before_cards) as item(code) group by code
    on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
  select jsonb_agg(to_jsonb(r) order by r.request_id) into baseline_requests
    from public.aamix_pack_requests r where r.user_id=main_uid;
  assert (select quantity from public.aamix_collection where user_id=main_uid and code='01c')=2;
  assert (select sum(quantity) from public.aamix_collection where user_id=main_uid)=45;

  first_repair := aamix_private.correct_promo_pack(opening_uid);
  assert first_repair->>'already_corrected'='false';
  assert (first_repair->>'collection_total')::bigint=45;
  assert jsonb_array_length(first_repair->'replacements')=1;
  assert first_repair->'replacements'->0->>'old'='01c';
  assert (first_repair->'replacements'->0->>'position')::integer=3;
  replacement := first_repair->'replacements'->0->>'new';
  assert exists(select 1 from aamix_private.reward_catalog
    where code=replacement and not is_promotional and card_class<>'Recurso' and special_weight=0),
    'Replacement is not an eligible normal card';

  select cards into corrected from public.aamix_pack_openings where opening_id=opening_uid;
  assert jsonb_array_length(corrected)=5;
  assert corrected=jsonb_set(before_cards,'{2}',to_jsonb(replacement),false),
    'Repair changed an unaffected position';
  assert not (corrected ?| array['01a','01b','01c','01d','01e','01f']);
  assert (select rules_version from public.aamix_pack_openings where opening_id=opening_uid)='0.10.1';
  assert (select revealed_at is not null from public.aamix_pack_openings where opening_id=opening_uid),
    'Repair reopened an already-revealed pack';
  assert (select sum(quantity) from public.aamix_collection where user_id=main_uid)=45,
    'Repair changed total collection quantity';
  assert (select quantity from public.aamix_collection where user_id=main_uid and code='01c')=1,
    'Repair removed the legitimate Maagover promotional copy';
  assert (select quantity from public.aamix_collection where user_id=main_uid and code='0100')=16,
    'Repair changed resource quantity';

  -- The signed gift, playable list and wallet are byte-for-byte the same rows.
  assert (select jsonb_agg(to_jsonb(d) order by d.deck_id) from public.aamix_owned_decks d where d.user_id=main_uid)=baseline_decks,
    'Repair changed the owned Maagover deck';
  assert (select jsonb_agg(to_jsonb(r) order by r.gift_code) from public.aamix_code_redemptions r where r.user_id=main_uid)=baseline_redemptions,
    'Repair changed the Maagover redemption';
  assert (select to_jsonb(w) from public.aamix_rewards_state w where w.user_id=main_uid)=baseline_wallet,
    'Repair changed the wallet';
  assert (select jsonb_agg(to_jsonb(r) order by r.request_id) from public.aamix_pack_requests r where r.user_id=main_uid)=baseline_requests,
    'Repair changed request aliases';
  assert (select previous_cards from aamix_private.pack_promo_corrections where opening_id=opening_uid)=before_cards,
    'Audit lost the original historical pack';
  assert (select corrected_cards from aamix_private.pack_promo_corrections where opening_id=opening_uid)=corrected;
  assert (select replacements from aamix_private.pack_promo_corrections where opening_id=opening_uid)=first_repair->'replacements';

  select jsonb_object_agg(code,quantity) into corrected_collection from public.aamix_collection where user_id=main_uid;
  select to_jsonb(o) into corrected_opening from public.aamix_pack_openings o where o.opening_id=opening_uid;
  select to_jsonb(a) into corrected_audit from aamix_private.pack_promo_corrections a where a.opening_id=opening_uid;
  for repeat_index in 1..3 loop
    second_repair := aamix_private.correct_promo_pack(opening_uid);
    assert second_repair->>'already_corrected'='true';
    assert second_repair->'replacements'=first_repair->'replacements';
    assert (select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=main_uid)=corrected_collection,
      'Repeated repair changed collection';
    assert (select to_jsonb(o) from public.aamix_pack_openings o where o.opening_id=opening_uid)=corrected_opening,
      'Repeated repair changed opening';
    assert (select to_jsonb(a) from aamix_private.pack_promo_corrections a where a.opening_id=opening_uid)=corrected_audit,
      'Repeated repair changed audit';
  end loop;

  -- Both old request UUIDs now return the corrected stored pack without a new draw.
  result := public.aamix_open_pack(first_request);
  assert result->'opening'->'cards'=corrected;
  assert (result->'opening'->>'opening_id')::uuid=opening_uid;
  result := public.aamix_open_pack(alias_request);
  assert result->'opening'->'cards'=corrected;
  assert (result->'opening'->>'opening_id')::uuid=opening_uid;
  assert (select count(*) from public.aamix_pack_openings where user_id=main_uid)=1;
  assert (select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=main_uid)=corrected_collection;
  assert (select to_jsonb(w) from public.aamix_rewards_state w where w.user_id=main_uid)=baseline_wallet;

  -- A missing awarded promo aborts the entire repair, including an earlier replacement.
  insert into public.aamix_rewards_state(user_id,packs) values(missing_uid,0);
  insert into public.aamix_pack_openings(opening_id,user_id,request_id,cards,revealed_at,rules_version)
    values(missing_opening_uid,missing_uid,gen_random_uuid(),missing_cards,now(),'0.10.0');
  insert into public.aamix_collection(user_id,code,quantity)
    values(missing_uid,'0100',1),(missing_uid,'01a',1),(missing_uid,'0104',1),(missing_uid,'0105',1);
  select jsonb_object_agg(code,quantity) into missing_collection from public.aamix_collection where user_id=missing_uid;
  select to_jsonb(o) into missing_opening from public.aamix_pack_openings o where o.opening_id=missing_opening_uid;
  begin
    perform aamix_private.correct_promo_pack(missing_opening_uid);
    raise exception 'QA repair unexpectedly succeeded with a missing awarded card';
  exception when raise_exception then
    if sqlerrm<>'Awarded promotional copy missing; inspect before repair' then raise; end if;
  end;
  assert (select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=missing_uid)=missing_collection,
    'Failed repair left a partial collection replacement';
  assert (select to_jsonb(o) from public.aamix_pack_openings o where o.opening_id=missing_opening_uid)=missing_opening,
    'Failed repair changed the historical opening';
  assert not exists(select 1 from aamix_private.pack_promo_corrections where opening_id=missing_opening_uid),
    'Failed repair left an audit success row';
  assert (select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=main_uid)=corrected_collection,
    'Another account repair changed the Maagover owner';
end $$;

select 'PASS: synthetic Maagover promo preserved; pack corrected; quantity conserved; retries and atomic failure verified. All fixtures roll back.' as promo_repair_qa;
rollback;
