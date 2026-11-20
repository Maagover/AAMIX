-- Focused 0.10.1 admin integration test. Run only after aamix_no_promo_packs.sql.
-- One synthetic confirmed account and three synthetic catalogue cards. No real awards.
-- No COMMIT. ROLLBACK restores fixtures and DDL; on any error, issue ROLLBACK too.
begin;
set local plpgsql.check_asserts = on;
create temporary table aamix_pack_exclusion_qa as
  select gen_random_uuid() as uid,
    'qa_promo_resource_'||gen_random_uuid()::text as resource_code,
    'qa_promo_normal_'||gen_random_uuid()::text as normal_code,
    '0000_qa_promo_special_'||gen_random_uuid()::text as special_code;
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@aamix-qa.invalid',now(),now(),now(),false from aamix_pack_exclusion_qa;
select set_config('request.jwt.claims',
  (select jsonb_build_object('sub',uid,'role','authenticated')::text from aamix_pack_exclusion_qa),true);
insert into aamix_private.catalog_codes(code)
  select resource_code from aamix_pack_exclusion_qa union all
  select normal_code from aamix_pack_exclusion_qa union all
  select special_code from aamix_pack_exclusion_qa;
-- Omitted flag deliberately verifies that unknown entries are excluded by default.
insert into aamix_private.reward_catalog(code,name,card_class,special_weight)
  select resource_code,'QA promotional Resource','Recurso',0 from aamix_pack_exclusion_qa union all
  select normal_code,'QA promotional normal','Aliado',0 from aamix_pack_exclusion_qa;
do $$
declare q record;
begin
  select * into strict q from pg_temp.aamix_pack_exclusion_qa;
  assert (select is_promotional from aamix_private.reward_catalog where code=q.resource_code);
  assert (select is_promotional from aamix_private.reward_catalog where code=q.normal_code);
  begin
    insert into aamix_private.reward_catalog(code,name,card_class,special_weight,is_promotional)
      values(q.special_code,'QA promotional Special','Aliado',100,true);
    raise exception 'Promotional Special weight was accepted';
  exception when check_violation then null; end;
end $$;
-- Test the Special branch filter independently of its catalogue constraint.
-- This DDL is transactional and MUST remain inside this BEGIN/ROLLBACK test.
alter table aamix_private.reward_catalog drop constraint aamix_promos_not_special;
insert into aamix_private.reward_catalog(code,name,card_class,special_weight,is_promotional)
  select special_code,'QA promotional Special','Aliado',100,true from aamix_pack_exclusion_qa;
-- Its code sorts before eligible Specials and has weight 100: without the filter,
-- every Special ticket would choose this fixture, rather than an eligible card.
create temporary table aamix_pack_exclusion_qa_result(sampled_packs integer,special_draws integer,normal_slot5_draws integer);
do $$
declare cards jsonb; i integer; slot integer; specials integer:=0; normals integer:=0;
begin
  assert exists(select 1 from aamix_private.reward_catalog where code='0100' and not is_promotional and card_class='Recurso');
  for i in 1..1000 loop
    cards:=aamix_private.draw_pack();
    assert jsonb_array_length(cards)=5;
    assert cards->>0='0100','Promotional synthetic Resource entered slot 1';
    for slot in 0..4 loop
      assert exists(select 1 from aamix_private.reward_catalog where code=cards->>slot and not is_promotional),
        'A promotional card entered a pack';
    end loop;
    for slot in 1..3 loop
      assert exists(select 1 from aamix_private.reward_catalog where code=cards->>slot and card_class<>'Recurso' and special_weight=0),
        'Slots 2-4 must contain eligible normal cards';
    end loop;
    assert cards->>4<>'0100','Resource entered slot 5';
    if exists(select 1 from aamix_private.reward_catalog where code=cards->>4 and special_weight>0) then
      specials:=specials+1;
    else
      normals:=normals+1;
    end if;
  end loop;
  assert specials>0 and normals>0,'Sample did not exercise both slot 5 branches';
  assert (select count(*) from public.aamix_pack_openings where user_id=(select uid from pg_temp.aamix_pack_exclusion_qa))=0;
  assert (select count(*) from public.aamix_collection where user_id=(select uid from pg_temp.aamix_pack_exclusion_qa))=0;
  insert into pg_temp.aamix_pack_exclusion_qa_result values(1000,specials,normals);
end $$;
select 'PASS: default exclusion, Resource/normal/Special filters and Special constraint; all fixtures and DDL rolled back' as validation,
  sampled_packs,special_draws,normal_slot5_draws from aamix_pack_exclusion_qa_result;
rollback;
