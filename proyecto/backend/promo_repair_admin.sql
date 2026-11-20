-- Administrative, explicit repair of an already awarded promotional pack.
-- No client execution privilege. Cards/decks obtained from other sources are preserved.
create table aamix_private.pack_promo_corrections (
  opening_id uuid primary key references public.aamix_pack_openings(opening_id),
  previous_cards jsonb not null,
  corrected_cards jsonb not null,
  replacements jsonb not null,
  corrected_at timestamptz not null default now()
);
alter table aamix_private.pack_promo_corrections enable row level security;
revoke all on aamix_private.pack_promo_corrections from public,anon,authenticated;

create function aamix_private.correct_promo_pack(p_opening_id uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare
  opening public.aamix_pack_openings%rowtype;
  prior aamix_private.pack_promo_corrections%rowtype;
  item record; replacement text; available integer;
  updated_cards jsonb := '[]'::jsonb; changes jsonb := '[]'::jsonb;
  before_total bigint; after_total bigint; owner_id uuid;
begin
  select user_id into strict owner_id from public.aamix_pack_openings where opening_id=p_opening_id;
  perform 1 from public.aamix_rewards_state where user_id=owner_id for update;
  select * into strict opening from public.aamix_pack_openings where opening_id=p_opening_id for update;
  select * into prior from aamix_private.pack_promo_corrections where opening_id=p_opening_id;
  if found then
    return jsonb_build_object('already_corrected',true,'replacements',prior.replacements);
  end if;
  select coalesce(sum(quantity),0) into before_total from public.aamix_collection where user_id=owner_id;
  for item in select value as code,ordinality as position from jsonb_array_elements_text(opening.cards) with ordinality loop
    if exists(select 1 from aamix_private.reward_catalog where code=item.code and is_promotional) then
      if item.position=1 then raise exception 'Resource slot repair requires a separate review'; end if;
      select code into strict replacement from aamix_private.reward_catalog
        where not is_promotional and card_class<>'Recurso' and special_weight=0 order by random() limit 1;
      select quantity into available from public.aamix_collection where user_id=owner_id and code=item.code for update;
      if coalesce(available,0)<1 then raise exception 'Awarded promotional copy missing; inspect before repair'; end if;
      if available=1 then
        delete from public.aamix_collection where user_id=owner_id and code=item.code;
      else
        update public.aamix_collection set quantity=quantity-1 where user_id=owner_id and code=item.code;
      end if;
      insert into public.aamix_collection(user_id,code,quantity) values(owner_id,replacement,1)
        on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+1;
      updated_cards := updated_cards || jsonb_build_array(replacement);
      changes := changes || jsonb_build_array(jsonb_build_object('position',item.position,'old',item.code,'new',replacement));
    else
      updated_cards := updated_cards || jsonb_build_array(item.code);
    end if;
  end loop;
  select coalesce(sum(quantity),0) into after_total from public.aamix_collection where user_id=owner_id;
  if before_total<>after_total then raise exception 'Repair changed total quantity'; end if;
  update public.aamix_pack_openings set cards=updated_cards,rules_version='0.10.1' where opening_id=p_opening_id;
  insert into aamix_private.pack_promo_corrections(opening_id,previous_cards,corrected_cards,replacements)
    values(p_opening_id,opening.cards,updated_cards,changes);
  return jsonb_build_object('already_corrected',false,'replacements',changes,'collection_total',after_total);
end $$;
revoke all on function aamix_private.correct_promo_pack(uuid) from public,anon,authenticated;
