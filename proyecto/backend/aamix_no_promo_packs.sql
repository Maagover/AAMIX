-- AAMIX0.10.1: author correction, 2026-10-17.
-- Apply after 20261017194519. No collection/deck quantities are changed.
-- New/unknown catalogue entries default to excluded until classified explicitly.
alter table aamix_private.reward_catalog add column is_promotional boolean not null default true;
update aamix_private.reward_catalog set is_promotional = code in ('01a','01b','01c','01d','01e','01f');
alter table aamix_private.reward_catalog add constraint aamix_promos_not_special check (not is_promotional or special_weight=0);

-- Preserve truthful historical results while enforcing the corrected rule for new packs.
alter table public.aamix_pack_openings add column rules_version text;
update public.aamix_pack_openings set rules_version='0.10.0' where rules_version is null;
alter table public.aamix_pack_openings alter column rules_version set default '0.10.1';
alter table public.aamix_pack_openings alter column rules_version set not null;
alter table public.aamix_pack_openings add constraint aamix_new_packs_no_promos
  check (rules_version='0.10.0' or not (cards ?| array['01a','01b','01c','01d','01e','01f']));

create or replace function aamix_private.draw_pack() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare codes jsonb := '[]'::jsonb; selected text; ticket double precision; slot integer;
begin
  perform aamix_private.reward_user();
  select code into strict selected from aamix_private.reward_catalog
    where not is_promotional and card_class='Recurso' order by random() limit 1;
  codes := codes || jsonb_build_array(selected);
  for slot in 2..5 loop
    if slot=5 and random()<0.30 then
      ticket := random()*100;
      select code into strict selected from (
        select code,sum(special_weight) over(order by code rows unbounded preceding) as cumulative
        from aamix_private.reward_catalog where not is_promotional and special_weight>0
      ) weighted where cumulative>ticket order by cumulative limit 1;
    else
      select code into strict selected from aamix_private.reward_catalog
        where not is_promotional and card_class<>'Recurso' and special_weight=0 order by random() limit 1;
    end if;
    codes := codes || jsonb_build_array(selected);
  end loop;
  if codes ?| array['01a','01b','01c','01d','01e','01f'] then
    raise exception 'Promotional cards are forbidden in packs' using errcode='23514';
  end if;
  return codes;
end $$;
revoke all on function aamix_private.draw_pack() from public,anon,authenticated;
notify pgrst,'reload schema';
