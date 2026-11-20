-- AAMIX 0.12.0. Additive extension after all five applied 0.11.0 migrations.
-- PREPARED ONLY. No player rows, prior redemptions, Auth/SMTP or pack rules change.
-- Match completion remains client-reported local-AI gameplay, not server validation.

alter table aamix_private.gift_code_rewards add column packs integer not null default 0 check(packs>=0);
alter table aamix_private.gift_code_rewards drop constraint gift_code_rewards_check;
alter table aamix_private.gift_code_rewards add constraint aamix_gift_reward_kind check (
  (deck_id is not null and cards is null and packs=0) or
  (deck_id is null and cards is not null and jsonb_typeof(cards)='array' and jsonb_array_length(cards)>0 and packs=0) or
  (deck_id is null and cards is null and packs>0)
);
insert into aamix_private.base_decks(id,name,cover,cards) values
 ('girabl','Mazo Girabl','0127','[{"codigo":"0127","cantidad":3},{"codigo":"01a","cantidad":3},{"codigo":"0108","cantidad":3},{"codigo":"0104","cantidad":2},{"codigo":"01b","cantidad":2},{"codigo":"0113","cantidad":2},{"codigo":"0112","cantidad":2},{"codigo":"0107","cantidad":1},{"codigo":"0111","cantidad":1},{"codigo":"01c","cantidad":1},{"codigo":"0116","cantidad":2},{"codigo":"0120","cantidad":3},{"codigo":"0124","cantidad":3},{"codigo":"0100","cantidad":12}]'::jsonb);
insert into aamix_private.gift_code_rewards(gift_code,reward_name,deck_id,cards,packs) values
 ('AAMIXTC','1 sobre',null,null,1),
 ('M4Z0G1R4','Mazo Girabl','girabl',null,0);

create table public.aamix_mission_claims (
  user_id uuid not null references auth.users(id) on delete cascade,
  mission_id text not null check(mission_id in ('win_one','play_ten')),
  period_key text not null,
  claimed_at timestamptz not null default now(),
  primary key(user_id,mission_id,period_key),
  check((mission_id='play_ten' and period_key='lifetime') or
        (mission_id='win_one' and period_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'))
);
alter table public.aamix_mission_claims enable row level security;
revoke all on public.aamix_mission_claims from public,anon,authenticated;
grant select on public.aamix_mission_claims to authenticated;
create policy mission_claims_owner_read on public.aamix_mission_claims for select to authenticated using((select auth.uid())=user_id);
create index aamix_finished_receipts_user_idx on public.aamix_match_receipts(user_id,finished_at) where finished_at is not null;

-- Read-only invoker helper: no caller-selected owner/date and no privileged access.
create function aamix_private.missions_status() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare
  uid uuid:=auth.uid(); today date:=(now() at time zone 'America/Santiago')::date;
  total_finished bigint; daily_finished bigint; daily_wins bigint; play_one jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select count(*),
    count(*) filter(where (finished_at at time zone 'America/Santiago')::date=today),
    count(*) filter(where result='victory' and (finished_at at time zone 'America/Santiago')::date=today)
    into total_finished,daily_finished,daily_wins
    from public.aamix_match_receipts where user_id=uid and finished_at is not null and result in('victory','defeat');
  play_one:=jsonb_build_object('id','play_one','title','Juega 1 partida','day',today,'timezone','America/Santiago',
    'progress',case when daily_finished>0 or exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today) then 1 else 0 end,
    'target',1,'claimed',exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today and claimed_at is not null),'reward_packs',1);
  return jsonb_build_array(
    play_one||jsonb_build_object('scope','daily'),
    jsonb_build_object('id','win_one','title','Gana 1 partida','scope','daily','day',today,'timezone','America/Santiago',
      'progress',least(daily_wins,1),'target',1,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='win_one' and period_key=today::text),'reward_packs',1),
    jsonb_build_object('id','play_ten','title','Juega 10 partidas','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_finished,10),'target',10,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='play_ten' and period_key='lifetime'),'reward_packs',5)
  );
end $$;
revoke all on function aamix_private.missions_status() from public,anon,authenticated;
grant execute on function aamix_private.missions_status() to authenticated;

create or replace function public.aamix_inventory() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); missions jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  missions:=aamix_private.missions_status();
  return jsonb_build_object(
    'user_id',uid,
    'gift',(select jsonb_build_object('deck_id',deck_id,'awarded_at',awarded_at) from public.aamix_starter_gifts where user_id=uid),
    'collection',coalesce((select jsonb_object_agg(code,quantity) from public.aamix_collection where user_id=uid),'{}'::jsonb),
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'cards',cards,'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb)
  );
end $$;
revoke all on function public.aamix_inventory() from public,anon,authenticated;
grant execute on function public.aamix_inventory() to authenticated;

create function aamix_private.claim_mission(p_mission_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  uid uuid:=aamix_private.lock_rewards(); today date:=(now() at time zone 'America/Santiago')::date;
  status jsonb; already boolean; prize integer; receipt_id uuid; granted uuid; period text;
begin
  select m into status from jsonb_array_elements(aamix_private.missions_status()) m where m->>'id'=p_mission_id;
  if not found then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023'; end if;
  already:=(status->>'claimed')::boolean;
  prize:=(status->>'reward_packs')::integer;
  if not already then
    if (status->>'progress')::integer<(status->>'target')::integer then
      raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023';
    end if;
    if p_mission_id='play_one' then
      -- Preserve the original ledger: an old claim can never be claimed again.
      if not exists(select 1 from public.aamix_daily_missions where user_id=uid and mission_day=today) then
        select match_id into strict receipt_id from public.aamix_match_receipts
          where user_id=uid and finished_at is not null and result in('victory','defeat')
            and (finished_at at time zone 'America/Santiago')::date=today
          order by finished_at,match_id limit 1;
        insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id,completed_at)
          select uid,today,match_id,finished_at from public.aamix_match_receipts where user_id=uid and match_id=receipt_id;
      end if;
      update public.aamix_daily_missions set claimed_at=now() where user_id=uid and mission_day=today and claimed_at is null returning user_id into granted;
    else
      period:=case when p_mission_id='play_ten' then 'lifetime' else today::text end;
      insert into public.aamix_mission_claims(user_id,mission_id,period_key) values(uid,p_mission_id,period)
        on conflict(user_id,mission_id,period_key) do nothing returning user_id into granted;
    end if;
    if granted is not null then
      update public.aamix_rewards_state set packs=packs+prize where user_id=uid;
    else
      already:=true;
    end if;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_claimed',already,'mission_id',p_mission_id,'reward_packs',prize);
end $$;
revoke all on function aamix_private.claim_mission(text) from public,anon,authenticated;
grant execute on function aamix_private.claim_mission(text) to authenticated;
create function public.aamix_claim_mission(p_mission_id text) returns jsonb
language sql security invoker set search_path='' as $$ select aamix_private.claim_mission(p_mission_id); $$;
revoke all on function public.aamix_claim_mission(text) from public,anon,authenticated;
grant execute on function public.aamix_claim_mission(text) to authenticated;
create or replace function aamix_private.claim_daily_mission() returns jsonb
language sql security definer set search_path='' as $$ select aamix_private.claim_mission('play_one'); $$;
revoke all on function aamix_private.claim_daily_mission() from public,anon,authenticated;
grant execute on function aamix_private.claim_daily_mission() to authenticated;

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
  insert into public.aamix_code_redemptions(user_id,gift_code) values(uid,normalized)
    on conflict(user_id,gift_code) do nothing returning user_id into granted;
  if granted is not null then
    insert into public.aamix_collection(user_id,code,quantity)
      select uid,e->>'codigo',sum((e->>'cantidad')::integer)::integer
      from jsonb_array_elements(award_cards) e group by e->>'codigo' order by e->>'codigo'
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    if configured.deck_id is not null then
      insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards) values(uid,chosen.id,chosen.name,chosen.cover,chosen.cards)
        on conflict(user_id,deck_id) do nothing;
    end if;
    if configured.packs>0 then update public.aamix_rewards_state set packs=packs+configured.packs where user_id=uid; end if;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_redeemed',granted is null,'redeemed_code',normalized,
    'reward_name',configured.reward_name,'reward_deck_id',configured.deck_id,'reward_cards',award_cards,'reward_packs',configured.packs);
end $$;
revoke all on function aamix_private.redeem_code(text) from public,anon,authenticated;
grant execute on function aamix_private.redeem_code(text) to authenticated;
notify pgrst,'reload schema';
