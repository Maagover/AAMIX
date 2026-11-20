-- Read-only deployment and preservation evidence. No UUID, email or card data returned.
select jsonb_build_object(
  'aggregates',jsonb_build_object(
    'collection_quantity',(select coalesce(sum(quantity),0) from public.aamix_collection),
    'owned_decks',(select count(*) from public.aamix_owned_decks),
    'redemptions',(select count(*) from public.aamix_code_redemptions),
    'receipts',(select count(*) from public.aamix_match_receipts),
    'completed_receipts',(select count(*) from public.aamix_match_receipts where finished_at is not null),
    'mission_claims',(select count(*) from public.aamix_mission_claims),
    'daily_claims',(select count(*) from public.aamix_daily_missions where claimed_at is not null),
    'packs',(select coalesce(sum(packs),0) from public.aamix_rewards_state),
    'qa_users',(select count(*) from auth.users where email like '%aamix-v014-qa.invalid'),
    'challenge_completions',(select count(*) from public.aamix_challenge_completions)),
  'old_field_hashes',jsonb_build_object(
    'collection',(select md5(coalesce(jsonb_agg(to_jsonb(t) order by user_id,code)::text,'[]')) from public.aamix_collection t),
    'decks',(select md5(coalesce(jsonb_agg(to_jsonb(t) order by user_id,deck_id)::text,'[]')) from public.aamix_owned_decks t),
    'redemptions',(select md5(coalesce(jsonb_agg(to_jsonb(t) order by user_id,gift_code)::text,'[]')) from public.aamix_code_redemptions t),
    'receipts_old_fields',(select md5(coalesce(jsonb_agg(to_jsonb(t)-'challenge_stage'-'challenge_opponent' order by match_id)::text,'[]')) from public.aamix_match_receipts t),
    'mission_claims_old_fields',(select md5(coalesce(jsonb_agg(to_jsonb(t)-'reward_packs' order by user_id,mission_id,period_key)::text,'[]')) from public.aamix_mission_claims t),
    'daily_missions',(select md5(coalesce(jsonb_agg(to_jsonb(t) order by user_id,mission_day)::text,'[]')) from public.aamix_daily_missions t),
    'wallet',(select md5(coalesce(jsonb_agg(to_jsonb(t) order by user_id)::text,'[]')) from public.aamix_rewards_state t),
    'openings',(select md5(coalesce(jsonb_agg(to_jsonb(t) order by opening_id)::text,'[]')) from public.aamix_pack_openings t),
    'starter',(select md5(coalesce(jsonb_agg(to_jsonb(t) order by user_id)::text,'[]')) from public.aamix_starter_gifts t)),
  'public_functions',(select jsonb_agg(jsonb_build_object('name',p.proname,'definer',p.prosecdef,'config',p.proconfig,
      'args',pg_get_function_arguments(p.oid),'anon_execute',has_function_privilege('anon',p.oid,'execute'),
      'authenticated_execute',has_function_privilege('authenticated',p.oid,'execute')) order by p.proname)
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
      and p.proname in('aamix_inventory','aamix_begin_match','aamix_begin_challenge_match','aamix_finish_match','aamix_claim_mission')),
  'completion_RLS',(select relrowsecurity from pg_class where oid='public.aamix_challenge_completions'::regclass),
  'completion_policies',(select jsonb_agg(jsonb_build_object('command',cmd,'roles',roles,'using',qual))
    from pg_policies where schemaname='public' and tablename='aamix_challenge_completions'),
  'claim_amounts_valid',not exists(select 1 from public.aamix_mission_claims where reward_packs is null or reward_packs<=0),
  'gift_code_definitions',(select count(*) from aamix_private.gift_code_rewards),
  'base_decks',(select jsonb_agg(jsonb_build_object('id',id,'cards',(select sum((c->>'cantidad')::integer)
    from jsonb_array_elements(cards) c),'resources',(select sum((c->>'cantidad')::integer)
    from jsonb_array_elements(cards) c where c->>'codigo'='0100')) order by id) from aamix_private.base_decks),
  'pack_eligible',(select count(*) from aamix_private.reward_catalog where not is_promotional)
) as verification;
