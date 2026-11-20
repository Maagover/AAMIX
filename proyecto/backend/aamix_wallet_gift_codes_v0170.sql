-- AAMIX 0.17.0. Additive gift configuration and serialized wallet rewards.
-- Prepared for review. Existing eight codes and every redemption remain intact.
-- No player balance backfill, starter grant, Auth setting or pack draw changes.

alter table aamix_private.gift_code_rewards
  add column restos bigint not null default 0 check(restos>=0),
  add column normal_packs integer not null default 0 check(normal_packs>=0);
alter table aamix_private.gift_code_rewards drop constraint aamix_gift_reward_kind;
alter table aamix_private.gift_code_rewards add constraint aamix_gift_reward_kind check (
  (deck_id is not null and cards is null and packs=0 and restos=0 and normal_packs=0) or
  (deck_id is null and cards is not null and jsonb_typeof(cards)='array' and jsonb_array_length(cards)>0
    and packs=0 and restos=0 and normal_packs=0) or
  (deck_id is null and cards is null and (packs>0 or restos>0 or normal_packs>0))
);
insert into aamix_private.gift_code_rewards(gift_code,reward_name,deck_id,cards,packs,restos,normal_packs) values
  ('AAMIX50','50 Restos',null,null,0,50,0),
  ('AAMIX100','100 Restos',null,null,0,100,0),
  ('AAMIX1000','1000 Restos',null,null,0,1000,0),
  ('AAMIXNAVIDAD','1 sobre TC, 50 Restos y 1 carta aleatoria',null,null,1,50,1);

create or replace function aamix_private.redeem_code(p_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  uid uuid:=aamix_private.lock_rewards(); normalized text:=upper(btrim(p_code));
  configured aamix_private.gift_code_rewards%rowtype; chosen aamix_private.base_decks%rowtype;
  award_cards jsonb:='[]'::jsonb; granted uuid;
begin
  select * into configured from aamix_private.gift_code_rewards where gift_code=normalized;
  if not found then raise exception 'AAMIX_INVALID_CODE' using errcode='22023'; end if;
  if configured.deck_id is not null then
    select * into strict chosen from aamix_private.base_decks where id=configured.deck_id;
    award_cards:=chosen.cards;
  elsif configured.cards is not null then award_cards:=configured.cards;
  end if;
  if exists(select 1 from jsonb_array_elements(award_cards) e
      where not exists(select 1 from aamix_private.catalog_codes c where c.code=e->>'codigo')
         or coalesce((e->>'cantidad')::integer,0)<=0) then
    raise exception 'Invalid server reward configuration' using errcode='22023';
  end if;
  -- Nested lock is safe: all balance writers serialize on this same UUID row.
  -- The existing registration currency award remains exactly once per account.
  perform aamix_private.ensure_restos_welcome();
  insert into public.aamix_code_redemptions(user_id,gift_code) values(uid,normalized)
    on conflict(user_id,gift_code) do nothing returning user_id into granted;
  if granted is not null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',sum((e->>'cantidad')::integer)::integer
      from jsonb_array_elements(award_cards) e group by e->>'codigo' order by e->>'codigo'
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    if configured.deck_id is not null then
      insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
        values(uid,chosen.id,chosen.name,chosen.cover,chosen.cards) on conflict(user_id,deck_id) do nothing;
    end if;
    update public.aamix_rewards_state set packs=packs+configured.packs,
      restos=restos+configured.restos,normal_packs=normal_packs+configured.normal_packs where user_id=uid;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_redeemed',granted is null,'redeemed_code',normalized,
    'reward_name',configured.reward_name,'reward_deck_id',configured.deck_id,'reward_cards',award_cards,
    'reward_packs',configured.packs,'reward_restos',configured.restos,'reward_normal_packs',configured.normal_packs);
end $$;
revoke all on function aamix_private.redeem_code(text) from public,anon,authenticated;
grant execute on function aamix_private.redeem_code(text) to authenticated;
-- Existing public invoker wrapper and its authenticated-only permission survive.
notify pgrst,'reload schema';
