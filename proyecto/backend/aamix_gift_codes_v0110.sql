-- AAMIX 0.11.0. Additive change after aamix_packs_exclude_promotional_v0101.
-- Prepared only: root must review/apply. No Auth/SMTP, existing user/card/deck,
-- starter reward, pack draw or historical opening changes.
-- User-confirmed codes; all redemptions are once per UUID using the existing PK.

create table aamix_private.gift_code_rewards (
  gift_code text primary key check (gift_code = upper(btrim(gift_code)) and length(gift_code) > 0),
  reward_name text not null,
  deck_id text references aamix_private.base_decks(id),
  cards jsonb,
  check (
    (deck_id is not null and cards is null) or
    (deck_id is null and cards is not null and jsonb_typeof(cards)='array' and jsonb_array_length(cards)>0)
  )
);
alter table aamix_private.gift_code_rewards enable row level security;
revoke all on aamix_private.gift_code_rewards from public,anon,authenticated;
-- No SELECT policies: private server-owned configuration is deliberately deny-all.
insert into aamix_private.gift_code_rewards(gift_code,reward_name,deck_id,cards) values
  ('M4Z0M44G0','Mazo Maagover','maago',null),
  ('P3RI','3 copias de Peri',null,'[{"codigo":"01a","cantidad":3}]'::jsonb),
  ('B1G0T3S','3 copias de Bigotes',null,'[{"codigo":"01b","cantidad":3}]'::jsonb),
  ('SI2TYA','Tsuki y Akira',null,'[{"codigo":"01c","cantidad":1}]'::jsonb),
  ('CHANCHULINES','Granjita de Chanchuus',null,'[{"codigo":"01d","cantidad":1}]'::jsonb),
  ('TORNEOAAMIX1','Dragón Tee K.O',null,'[{"codigo":"01e","cantidad":1}]'::jsonb);

create or replace function aamix_private.redeem_code(p_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  uid uuid := aamix_private.lock_rewards();
  normalized text := upper(btrim(p_code));
  configured aamix_private.gift_code_rewards%rowtype;
  chosen aamix_private.base_decks%rowtype;
  award_cards jsonb;
  granted uuid;
begin
  select * into configured from aamix_private.gift_code_rewards where gift_code=normalized;
  if not found then raise exception 'AAMIX_INVALID_CODE' using errcode='22023'; end if;
  if configured.deck_id is not null then
    select * into strict chosen from aamix_private.base_decks where id=configured.deck_id;
    award_cards:=chosen.cards;
  else
    award_cards:=configured.cards;
  end if;
  -- Reject malformed private configuration before touching the redemption gate.
  if exists(select 1 from jsonb_array_elements(award_cards) e
      where not exists(select 1 from aamix_private.catalog_codes c where c.code=e->>'codigo')
         or coalesce((e->>'cantidad')::integer,0)<=0) then
    raise exception 'Invalid server reward configuration' using errcode='22023';
  end if;
  insert into public.aamix_code_redemptions(user_id,gift_code) values(uid,normalized)
    on conflict(user_id,gift_code) do nothing returning user_id into granted;
  if granted is not null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',sum((e->>'cantidad')::integer)::integer
      from jsonb_array_elements(award_cards) e group by e->>'codigo' order by e->>'codigo'
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    if configured.deck_id is not null then
      insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
        values(uid,chosen.id,chosen.name,chosen.cover,chosen.cards)
        on conflict(user_id,deck_id) do nothing;
    end if;
  end if;
  return public.aamix_inventory() || jsonb_build_object(
    'already_redeemed',granted is null,
    'redeemed_code',normalized,
    'reward_name',configured.reward_name,
    'reward_deck_id',configured.deck_id,
    'reward_cards',award_cards
  );
end $$;
revoke all on function aamix_private.redeem_code(text) from public,anon,authenticated;
grant execute on function aamix_private.redeem_code(text) to authenticated;
-- Existing public invoker wrapper/signature and its permissions are preserved.

create or replace function aamix_private.set_avatar(p_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid := aamix_private.lock_rewards();
begin
  -- Promotional avatars remain locked even when the player owns their cards.
  -- New/unknown catalogue rows default to is_promotional=true (fail closed).
  if not exists(select 1 from aamix_private.reward_catalog
      where code=p_code and card_class='Aliado' and not is_promotional) then
    raise exception 'AAMIX_INVALID_AVATAR' using errcode='22023';
  end if;
  update public.aamix_rewards_state set avatar_code=p_code where user_id=uid;
  return public.aamix_inventory();
end $$;
revoke all on function aamix_private.set_avatar(text) from public,anon,authenticated;
grant execute on function aamix_private.set_avatar(text) to authenticated;
notify pgrst,'reload schema';
