create or replace function aamix_private.check_challenge_v170(p_uid uuid) returns void language plpgsql security definer set search_path='' as $$
declare d jsonb;
begin
 if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=4)then perform aamix_private.complete_milestone_v170(p_uid,'challenge_maagover');end if;
 if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=5)then perform aamix_private.complete_milestone_v170(p_uid,'challenge_girabl');end if;
 for d in select value from jsonb_array_elements(aamix_private.challenge_definitions()) where (value->>'stage')::integer>=6 loop
  if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=(d->>'stage')::integer)then perform aamix_private.complete_milestone_v170(p_uid,'challenge_design_'||(d->>'stage'));end if;
 end loop;
 if not exists(select 1 from jsonb_array_elements(aamix_private.challenge_definitions()) as definitions(entry) where not exists(select 1 from public.aamix_challenge_completions c where c.user_id=p_uid and c.stage=(definitions.entry->>'stage')::integer))then
  perform aamix_private.complete_milestone_v170(p_uid,'challenge_complete');
 end if;
end$$;
