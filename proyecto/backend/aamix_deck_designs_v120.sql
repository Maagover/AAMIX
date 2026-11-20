-- AAMIX 1.2: cosmetic custom-deck designs earned through gift codes.
-- Compatible with RPC contracts 1.0/1.1. No progress or inventory reset.
-- Ownership comes exclusively from the existing (user_id,gift_code) redemption ledger.

alter table aamix_private.gift_code_rewards add column deck_design text
  check(deck_design is null or deck_design in('custom_tsuki_akira','custom_chanchuus','custom_viborin'));
alter table aamix_private.gift_code_rewards drop constraint aamix_gift_reward_kind;
alter table aamix_private.gift_code_rewards add constraint aamix_gift_reward_kind check(
  (deck_design is null and (
    (deck_id is not null and cards is null and packs=0 and restos=0 and normal_packs=0)
    or (deck_id is null and cards is not null and jsonb_typeof(cards)='array' and jsonb_array_length(cards)>0 and packs=0 and restos=0 and normal_packs=0)
    or (deck_id is null and cards is null and (packs>0 or restos>0 or normal_packs>0))
  )) or (
    deck_design is not null and deck_id is null and cards is null and packs=0 and restos=0 and normal_packs=0
  )
);
insert into aamix_private.gift_code_rewards(gift_code,reward_name,deck_design)
values
  ('SI2MAZO','Diseño de mazo Tsuki y Akira','custom_tsuki_akira'),
  ('CHANCHUMAZO','Diseño de mazo Granjita de Chanchuus','custom_chanchuus'),
  ('VIBMAZO','Diseño de mazo Viborín','custom_viborin');

-- Entitlements are snapshots; later changes to code configuration cannot revoke or retarget an earned design.
-- Historical redemptions remain untouched with NULL design.
alter table public.aamix_code_redemptions add column deck_design text
  check(deck_design is null or deck_design in('custom_tsuki_akira','custom_chanchuus','custom_viborin'));

alter table public.aamix_custom_decks drop constraint aamix_custom_decks_cover_check;
alter table public.aamix_custom_decks add constraint aamix_custom_decks_cover_check
  check(cover in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin'));

-- Private helper has no user-id parameter and reveals only auth.uid() entitlements.
-- Defaults are always available. Earned covers do not require owning the pictured card.
create function aamix_private.deck_designs_inventory() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); unlocked jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select coalesce(jsonb_agg(design.id order by design.position),'[]'::jsonb) into unlocked
  from (values('custom_tsuki_akira',1),('custom_chanchuus',2),('custom_viborin',3)) design(id,position)
  where exists(
    select 1 from public.aamix_code_redemptions redeemed
    where redeemed.user_id=uid and redeemed.deck_design=design.id
  );
  return jsonb_build_object(
    'available_custom_covers','["custom_transmision","custom_restos"]'::jsonb||unlocked,
    'unlocked_deck_designs',unlocked);
end $$;
revoke all on function aamix_private.deck_designs_inventory() from public,anon,authenticated;
grant execute on function aamix_private.deck_designs_inventory() to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.save_custom_deck(p_request_id uuid, p_deck_id text, p_nombre text, p_portada text, p_cartas jsonb, p_draft boolean, p_expected_revision integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); d public.aamix_custom_decks%rowtype;
  old_request aamix_private.custom_deck_requests%rowtype; payload jsonb; saved jsonb; canonical_cards jsonb;
  normalized_id text:=coalesce(p_deck_id,''); normalized_name text:=btrim(p_nombre);
begin
  if p_request_id is null or p_expected_revision is null or p_expected_revision<0 or p_draft is null
    or normalized_name is null or char_length(normalized_name) not between 1 and 48 or normalized_name ~ '[[:cntrl:]]'
    or p_portada is null or p_portada not in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin')
    or p_cartas is null or octet_length(p_cartas::text)>8192 then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;
  payload:=jsonb_build_object('id',normalized_id,'nombre',normalized_name,'portada',p_portada,'cartas',p_cartas,'draft',p_draft,'expected_revision',p_expected_revision);
  select * into old_request from aamix_private.custom_deck_requests where user_id=uid and request_id=p_request_id;
  if found then
    if old_request.payload<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return public.aamix_inventory()||jsonb_build_object('saved_deck',old_request.saved_deck,'last_saved_deck',old_request.saved_deck);
  end if;
  if p_portada not in('custom_transmision','custom_restos') and not exists(
    select 1 from public.aamix_code_redemptions redeemed
    where redeemed.user_id=uid and redeemed.deck_design=p_portada
  ) then raise exception 'AAMIX_DECK_COVER_LOCKED' using errcode='22023'; end if;
  canonical_cards:=aamix_private.custom_cards(uid,p_cartas,p_draft);
  if normalized_id='' then
    if p_expected_revision<>0 then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001'; end if;
    normalized_id:='custom_'||gen_random_uuid()::text;
    insert into aamix_private.deck_registry(id) values(normalized_id);
    insert into public.aamix_custom_decks(user_id,deck_id,name,cover,cards,draft)
      values(uid,normalized_id,normalized_name,p_portada,canonical_cards,p_draft) returning * into d;
  else
    if normalized_id !~ '^custom_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'AAMIX_DECK_IMMUTABLE' using errcode='22023'; end if;
    select * into d from public.aamix_custom_decks where user_id=uid and deck_id=normalized_id for update;
    if not found then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023'; end if;
    if d.revision<>p_expected_revision then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001'; end if;
    update public.aamix_custom_decks set name=normalized_name,cover=p_portada,cards=canonical_cards,draft=p_draft,revision=revision+1,updated_at=now()
      where user_id=uid and deck_id=normalized_id returning * into d;
  end if;
  saved:=jsonb_build_object('id',d.deck_id,'nombre',d.name,'portada',d.cover,'recurso_inicial','0100','cartas',d.cards,'custom',true,'draft',d.draft,'revision',d.revision);
  insert into aamix_private.custom_deck_requests(user_id,request_id,payload,saved_deck) values(uid,p_request_id,payload,saved);
  return public.aamix_inventory()||jsonb_build_object('saved_deck',saved,'last_saved_deck',saved);
end $function$;

CREATE OR REPLACE FUNCTION public.aamix_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); missions jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  missions:=aamix_private.missions_status();
  return jsonb_build_object(
    'user_id',uid,'welcome_pack',aamix_private.welcome_status(),
    'restos_welcome_claimed',exists(select 1 from public.aamix_restos_welcome where user_id=uid),
    'restos',coalesce((select restos from public.aamix_rewards_state where user_id=uid),0),
    'normal_packs',coalesce((select normal_packs from public.aamix_rewards_state where user_id=uid),0),
    'shop',aamix_private.shop_catalog(),
    'gift',(select jsonb_build_object('deck_id',deck_id,'awarded_at',awarded_at) from public.aamix_starter_gifts where user_id=uid),
    'collection',coalesce((select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=uid),'{}'::jsonb),
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'custom_decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'custom',true,'draft',draft,'revision',revision) order by created_at,deck_id) from public.aamix_custom_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'kind',kind,'cards',cards,'new_card_indices',to_jsonb(new_card_indices),'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb))||aamix_private.deck_designs_inventory();
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.redeem_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid:=aamix_private.lock_rewards(); normalized text:=upper(btrim(p_code));
  configured aamix_private.gift_code_rewards%rowtype; chosen aamix_private.base_decks%rowtype;
  award_cards jsonb:='[]'::jsonb; granted uuid; claimed_design text;
begin
  -- A redeemed cosmetic code is a stable receipt, even if future code metadata changes or expires.
  select deck_design into claimed_design from public.aamix_code_redemptions where user_id=uid and gift_code=normalized;
  if claimed_design is not null then
    return public.aamix_inventory()||jsonb_build_object('already_redeemed',true,'redeemed_code',normalized,
      'reward_name',case claimed_design when 'custom_tsuki_akira' then 'Diseño de mazo Tsuki y Akira'
        when 'custom_chanchuus' then 'Diseño de mazo Granjita de Chanchuus' when 'custom_viborin' then 'Diseño de mazo Viborín' end,
      'reward_deck_id',null,'reward_cards','[]'::jsonb,'reward_packs',0,'reward_restos',0,'reward_normal_packs',0,
      'reward_cover',claimed_design,'reward_design',claimed_design);
  end if;
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
  if configured.deck_design is null then perform aamix_private.ensure_restos_welcome(); end if;
  insert into public.aamix_code_redemptions(user_id,gift_code,deck_design) values(uid,normalized,configured.deck_design)
    on conflict(user_id,gift_code) do nothing returning user_id into granted;
  if granted is not null and configured.deck_design is null then
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
  if granted is not null then claimed_design:=configured.deck_design; end if;
  return public.aamix_inventory()||jsonb_build_object('already_redeemed',granted is null,'redeemed_code',normalized,
    'reward_name',configured.reward_name,'reward_deck_id',configured.deck_id,'reward_cards',award_cards,
    'reward_packs',configured.packs,'reward_restos',configured.restos,'reward_normal_packs',configured.normal_packs,
    'reward_cover',claimed_design,'reward_design',claimed_design);
end $function$;

notify pgrst,'reload schema';

