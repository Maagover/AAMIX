-- Eight focused assertions, administrator session only, after the reset.
-- Uses one confirmed captured account through transaction-local auth.uid().
-- ALL awards and starter choices below roll back; Auth is never changed.
begin;
set local lock_timeout='8s';
set local statement_timeout='60s';
do $$
declare b aamix_release_backup.batches%rowtype; uid uuid; first jsonb; repeated jsonb; inventory jsonb; s record; current_rows jsonb;
begin
  perform aamix_release_backup.require_admin();
  select * into strict b from aamix_release_backup.batches where label='aamix-v1.0-official-progress-reset-2026-10-19';
  assert b.reset_at is not null and b.restored_at is null,'1 official reset completed once';
  assert not has_schema_privilege('anon','aamix_release_backup','USAGE')
    and not has_schema_privilege('authenticated','aamix_release_backup','USAGE')
    and not has_schema_privilege('service_role','aamix_release_backup','USAGE')
    and not has_function_privilege('authenticated','aamix_release_backup.restore(uuid)','EXECUTE')
    and (select bool_and(c.relrowsecurity) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='aamix_release_backup' and c.relkind='r'),
    '2 backup tables and recovery tools are private and RLS enabled';
  assert aamix_release_backup.auth_fingerprint(b.user_ids)=b.auth_fingerprint,'3 preserved Auth identities checksum';
  for s in select * from aamix_release_backup.table_snapshots where batch_id=b.batch_id loop
    current_rows:=aamix_release_backup.capture_rows(s.table_name::regclass,s.predicate_mode,b.user_ids,b.room_ids,b.opening_ids);
    if current_rows<>'[]'::jsonb then raise exception 'Progress not empty before bootstrap: %',s.table_name; end if;
  end loop;
  assert not exists(select 1 from auth.users where id=any(b.user_ids) and coalesce(raw_user_meta_data,'{}'::jsonb)?'qa_run'), '4 captured accounts exclude synthetic QA users and all game tables are empty';
  select id into strict uid from auth.users where id=any(b.user_ids) and email_confirmed_at is not null order by id limit 1;
  perform set_config('request.jwt.claim.sub',uid::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated')::text,true);
  inventory:=public.aamix_inventory();
  assert inventory->>'restos'='0' and inventory->>'packs'='0' and inventory->'decks'='[]'::jsonb and inventory->'collection'='{}'::jsonb,'5 clean account before login awards';
  first:=public.aamix_claim_restos_welcome();
  first:=public.aamix_claim_welcome_pack();
  assert first->>'restos'='100' and first->>'packs'='1' and first->'decks'='[]'::jsonb and first->'collection'='{}'::jsonb,'6 new login receives exactly 100 Restos and one TC pack without a starter deck';
  repeated:=public.aamix_claim_restos_welcome();
  repeated:=public.aamix_claim_welcome_pack();
  assert repeated->>'restos'='100' and repeated->>'packs'='1','7 repeated bootstrap does not duplicate awards';
  perform public.aamix_enter_challenge();
  inventory:=public.aamix_claim_starter('papito');
  assert jsonb_array_length(inventory->'decks')=1
    and (select sum(quantity) from public.aamix_collection where user_id=uid)=40
    and inventory->>'restos'='100' and inventory->>'packs'='1','8 starter deck is available only when entering the challenge';
end $$;
select jsonb_build_object('release_bootstrap_checks',8,'status','passed; all temporary rewards roll back next') as verification;
rollback;
