-- AAMIX 0.15.0: one welcome TC pack, starter deck on entering the challenge.
-- Existing starter gifts, quantities, claims and rewards are preserved.
create table public.aamix_welcome_packs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  packs integer not null default 1 check(packs=1),
  challenge_entered_at timestamptz
);
alter table public.aamix_welcome_packs enable row level security;
revoke all on public.aamix_welcome_packs from public,anon,authenticated;
grant select on public.aamix_welcome_packs to authenticated;
create policy welcome_owner_read on public.aamix_welcome_packs for select to authenticated
  using((select auth.uid())=user_id);

create function aamix_private.welcome_status() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); legacy boolean; welcome public.aamix_welcome_packs%rowtype;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  legacy:=exists(select 1 from public.aamix_starter_gifts where user_id=uid);
  select * into welcome from public.aamix_welcome_packs where user_id=uid;
  return jsonb_build_object('claimed',legacy or welcome.user_id is not null,
    'granted',welcome.user_id is not null,'legacy_starter',legacy,
    'challenge_entered',legacy or welcome.challenge_entered_at is not null);
end $$;
revoke all on function aamix_private.welcome_status() from public,anon,authenticated;
grant execute on function aamix_private.welcome_status() to authenticated;

create or replace function public.aamix_inventory() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); missions jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  missions:=aamix_private.missions_status();
  return jsonb_build_object(
    'user_id',uid,'welcome_pack',aamix_private.welcome_status(),
    'gift',(select jsonb_build_object('deck_id',deck_id,'awarded_at',awarded_at) from public.aamix_starter_gifts where user_id=uid),
    'collection',coalesce((select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=uid),'{}'::jsonb),
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'cards',cards,'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb));
end $$;

create function aamix_private.claim_welcome_pack() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); granted uuid;
begin
  if not exists(select 1 from public.aamix_starter_gifts where user_id=uid) then
    insert into public.aamix_welcome_packs(user_id) values(uid)
      on conflict(user_id) do nothing returning user_id into granted;
    if granted is not null then update public.aamix_rewards_state set packs=packs+1 where user_id=uid; end if;
  end if;
  return public.aamix_inventory()||jsonb_build_object('welcome_awarded',granted is not null,
    'welcome_reward_packs',case when granted is null then 0 else 1 end);
end $$;
revoke all on function aamix_private.claim_welcome_pack() from public,anon,authenticated;
grant execute on function aamix_private.claim_welcome_pack() to authenticated;
create function public.aamix_claim_welcome_pack() returns jsonb
language sql security invoker set search_path='' as $$ select aamix_private.claim_welcome_pack(); $$;
revoke all on function public.aamix_claim_welcome_pack() from public,anon,authenticated;
grant execute on function public.aamix_claim_welcome_pack() to authenticated;

create function aamix_private.enter_challenge() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); ignored jsonb;
begin
  ignored:=aamix_private.claim_welcome_pack();
  update public.aamix_welcome_packs set challenge_entered_at=coalesce(challenge_entered_at,now()) where user_id=uid;
  return public.aamix_inventory();
end $$;
revoke all on function aamix_private.enter_challenge() from public,anon,authenticated;
grant execute on function aamix_private.enter_challenge() to authenticated;
create function public.aamix_enter_challenge() returns jsonb
language sql security invoker set search_path='' as $$ select aamix_private.enter_challenge(); $$;
revoke all on function public.aamix_enter_challenge() from public,anon,authenticated;
grant execute on function public.aamix_enter_challenge() to authenticated;

create or replace function aamix_private.claim_starter(p_deck_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); chosen aamix_private.base_decks%rowtype; granted uuid;
begin
  if p_deck_id is null or p_deck_id not in('kajido','flaan','papito') then raise exception 'Unknown base deck' using errcode='22023'; end if;
  if not exists(select 1 from public.aamix_starter_gifts where user_id=uid) and not exists(
    select 1 from public.aamix_welcome_packs where user_id=uid and challenge_entered_at is not null) then
    raise exception 'AAMIX_START_CHALLENGE' using errcode='22023';
  end if;
  select * into strict chosen from aamix_private.base_decks where id=p_deck_id;
  insert into public.aamix_starter_gifts(user_id,deck_id) values(uid,chosen.id)
    on conflict(user_id) do nothing returning user_id into granted;
  if granted is not null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',(e->>'cantidad')::integer from jsonb_array_elements(chosen.cards) e order by e->>'codigo'
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards) values(uid,chosen.id,chosen.name,chosen.cover,chosen.cards)
      on conflict(user_id,deck_id) do nothing;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_claimed',granted is null);
end $$;
notify pgrst,'reload schema';
