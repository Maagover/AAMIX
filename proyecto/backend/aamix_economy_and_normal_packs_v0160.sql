-- AAMIX 0.16.0. Prepared for review; the deployment tool assigns its migration ID.
-- Additive economy. Historic quantities, mission claims and pack results remain intact.
-- Local-AI match outcomes remain client-reported, as in the previous releases.

alter table public.aamix_rewards_state
  add column restos bigint not null default 0 check(restos>=0),
  add column normal_packs integer not null default 0 check(normal_packs>=0);

create table public.aamix_restos_welcome (
  user_id uuid primary key references auth.users(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  amount integer not null default 100 check(amount=100)
);
create table public.aamix_shop_purchases (
  purchase_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  code text not null references aamix_private.reward_catalog(code),
  price integer not null check(price in(150,500)),
  purchased_at timestamptz not null default now(),
  unique(user_id,request_id)
);
create index aamix_shop_purchases_code_idx on public.aamix_shop_purchases(code);
-- The new daily rewards have their own ledger. Prior pack rewards are historical
-- facts and cannot be deleted, converted or paid again through a legacy endpoint.
create table public.aamix_daily_claims_v016 (
  user_id uuid not null references auth.users(id) on delete cascade,
  mission_id text not null check(mission_id in('play_one','win_one')),
  mission_day date not null,
  completed_match_id uuid not null references public.aamix_match_receipts(match_id),
  claimed_at timestamptz not null default now(),
  reward_kind text not null,
  reward_amount integer not null,
  primary key(user_id,mission_id,mission_day),
  check((mission_id='play_one' and reward_kind='restos' and reward_amount=50) or
        (mission_id='win_one' and reward_kind='normal_pack' and reward_amount=1))
);
create index aamix_daily_claims_v016_match_idx on public.aamix_daily_claims_v016(completed_match_id);
alter table public.aamix_restos_welcome enable row level security;
alter table public.aamix_shop_purchases enable row level security;
alter table public.aamix_daily_claims_v016 enable row level security;
revoke all on public.aamix_restos_welcome,public.aamix_shop_purchases,public.aamix_daily_claims_v016 from public,anon,authenticated;
grant select on public.aamix_restos_welcome,public.aamix_shop_purchases,public.aamix_daily_claims_v016 to authenticated;
create policy restos_welcome_owner_read on public.aamix_restos_welcome for select to authenticated using((select auth.uid())=user_id);
create policy shop_purchases_owner_read on public.aamix_shop_purchases for select to authenticated using((select auth.uid())=user_id);
create policy daily_claims_v016_owner_read on public.aamix_daily_claims_v016 for select to authenticated using((select auth.uid())=user_id);

alter table public.aamix_pack_openings add column kind text not null default 'tc' check(kind in('tc','normal_card'));
alter table public.aamix_pack_openings drop constraint aamix_pack_openings_cards_check;
alter table public.aamix_pack_openings add constraint aamix_pack_openings_shape check(
  jsonb_typeof(cards)='array' and jsonb_array_length(cards)=case kind when 'tc' then 5 when 'normal_card' then 1 end);
alter table public.aamix_pack_openings add constraint aamix_normal_card_exclusions check(
  kind<>'normal_card' or not(cards ?| array['0100','0103','0105','0115','0119','0125','0128','0130','0131','0134','01a','01b','01c','01d','01e','01f']));

-- Only this read helper sees the internal catalogue. Clients cannot edit prices.
create function aamix_private.shop_catalog() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform aamix_private.reward_user();
  return coalesce((select jsonb_agg(jsonb_build_object('code',code,'price',
    case when code in('0103','0105','0115','0119') then 500 else 150 end) order by code)
    from aamix_private.reward_catalog where not is_promotional and card_class<>'Recurso'),'[]'::jsonb);
end $$;
revoke all on function aamix_private.shop_catalog() from public,anon,authenticated;
grant execute on function aamix_private.shop_catalog() to authenticated;

create or replace function aamix_private.missions_status() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); today date:=(now() at time zone 'America/Santiago')::date;
  total_finished bigint; total_wins bigint; daily_finished bigint; daily_wins bigint;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select count(*),count(*) filter(where result='victory'),
    count(*) filter(where (finished_at at time zone 'America/Santiago')::date=today),
    count(*) filter(where result='victory' and (finished_at at time zone 'America/Santiago')::date=today)
    into total_finished,total_wins,daily_finished,daily_wins from public.aamix_match_receipts
    where user_id=uid and finished_at is not null and result in('victory','defeat');
  return jsonb_build_array(
    jsonb_build_object('id','play_one','title','Juega 1 partida','scope','daily','day',today,'timezone','America/Santiago',
      'progress',least(daily_finished,1),'target',1,'claimed',exists(select 1 from public.aamix_daily_claims_v016 where user_id=uid and mission_id='play_one' and mission_day=today),
      'reward_kind','restos','reward_amount',50,'reward_packs',0),
    jsonb_build_object('id','win_one','title','Gana 1 partida','scope','daily','day',today,'timezone','America/Santiago',
      'progress',least(daily_wins,1),'target',1,'claimed',exists(select 1 from public.aamix_daily_claims_v016 where user_id=uid and mission_id='win_one' and mission_day=today),
      'reward_kind','normal_pack','reward_amount',1,'reward_packs',0),
    jsonb_build_object('id','play_ten','title','Juega 10 partidas','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_finished,10),'target',10,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='play_ten' and period_key='lifetime'),
      'reward_kind','tc_pack','reward_amount',3,'reward_packs',3),
    jsonb_build_object('id','win_ten','title','Gana 10 partidas','scope','lifetime','day',null,'timezone','America/Santiago',
      'progress',least(total_wins,10),'target',10,'claimed',exists(select 1 from public.aamix_mission_claims where user_id=uid and mission_id='win_ten' and period_key='lifetime'),
      'reward_kind','tc_pack','reward_amount',5,'reward_packs',5));
end $$;

create or replace function public.aamix_inventory() returns jsonb
language plpgsql security invoker set search_path='' as $$
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
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'kind',kind,'cards',cards,'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb));
end $$;

-- All writers share the existing per-UUID wallet lock. There is no caller owner,
-- price, reward amount or balance parameter on any public endpoint.
create function aamix_private.ensure_restos_welcome() returns boolean
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); granted uuid;
begin
  insert into public.aamix_restos_welcome(user_id) values(uid) on conflict(user_id) do nothing returning user_id into granted;
  if granted is not null then update public.aamix_rewards_state set restos=restos+100 where user_id=uid; end if;
  return granted is not null;
end $$;
revoke all on function aamix_private.ensure_restos_welcome() from public,anon,authenticated;
create function aamix_private.claim_restos_welcome() returns jsonb
language plpgsql security definer set search_path='' as $$
declare awarded boolean:=aamix_private.ensure_restos_welcome();
begin
  return public.aamix_inventory()||jsonb_build_object('restos_awarded',awarded,'restos_reward',case when awarded then 100 else 0 end);
end $$;
create function public.aamix_claim_restos_welcome() returns jsonb
language sql security invoker set search_path='' as $$ select aamix_private.claim_restos_welcome(); $$;

create function aamix_private.purchase_card(p_request_id uuid,p_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_shop_purchases%rowtype;
  cost integer; already boolean;
begin
  if p_request_id is null then raise exception 'Purchase request UUID required' using errcode='22023'; end if;
  select * into receipt from public.aamix_shop_purchases where user_id=uid and request_id=p_request_id;
  already:=found;
  if already then
    if receipt.code is distinct from p_code then raise exception 'AAMIX_PURCHASE_REQUEST_MISMATCH' using errcode='22023'; end if;
  else
    select case when code in('0103','0105','0115','0119') then 500 else 150 end into cost
      from aamix_private.reward_catalog where code=p_code and not is_promotional and card_class<>'Recurso';
    if not found then raise exception 'AAMIX_CARD_NOT_FOR_SALE' using errcode='22023'; end if;
    perform aamix_private.ensure_restos_welcome();
    update public.aamix_rewards_state set restos=restos-cost where user_id=uid and restos>=cost;
    if not found then raise exception 'AAMIX_INSUFFICIENT_RESTOS' using errcode='22023'; end if;
    insert into public.aamix_shop_purchases(user_id,request_id,code,price) values(uid,p_request_id,p_code,cost) returning * into receipt;
    insert into public.aamix_collection(user_id,code,quantity) values(uid,p_code,1)
      on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+1;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_purchased',already,'purchase_code',receipt.code,'purchase_price',receipt.price,
    'purchase',jsonb_build_object('purchase_id',receipt.purchase_id,'request_id',receipt.request_id,'code',receipt.code,'price',receipt.price,'purchased_at',receipt.purchased_at));
end $$;
create function public.aamix_purchase_card(p_request_id uuid,p_code text) returns jsonb
language sql security invoker set search_path='' as $$ select aamix_private.purchase_card(p_request_id,p_code); $$;

create or replace function aamix_private.claim_mission(p_mission_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); today date:=(now() at time zone 'America/Santiago')::date;
  status jsonb; already boolean; amount integer; kind text; receipt_id uuid; granted uuid;
begin
  select m into status from jsonb_array_elements(aamix_private.missions_status()) m where m->>'id'=p_mission_id;
  if not found then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023'; end if;
  already:=(status->>'claimed')::boolean; amount:=(status->>'reward_amount')::integer; kind:=status->>'reward_kind';
  if already and kind='tc_pack' then
    select reward_packs into strict amount from public.aamix_mission_claims where user_id=uid and mission_id=p_mission_id and period_key='lifetime';
  end if;
  if not already then
    if (status->>'progress')::integer<(status->>'target')::integer then raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023'; end if;
    perform aamix_private.ensure_restos_welcome();
    if p_mission_id in('play_one','win_one') then
      select match_id into strict receipt_id from public.aamix_match_receipts where user_id=uid and finished_at is not null
        and result in('victory','defeat') and (p_mission_id='play_one' or result='victory')
        and (finished_at at time zone 'America/Santiago')::date=today order by finished_at,match_id limit 1;
      insert into public.aamix_daily_claims_v016(user_id,mission_id,mission_day,completed_match_id,reward_kind,reward_amount)
        values(uid,p_mission_id,today,receipt_id,kind,amount) on conflict(user_id,mission_id,mission_day) do nothing returning user_id into granted;
    else
      insert into public.aamix_mission_claims(user_id,mission_id,period_key,reward_packs) values(uid,p_mission_id,'lifetime',amount)
        on conflict(user_id,mission_id,period_key) do nothing returning user_id into granted;
    end if;
    if granted is not null then
      if kind='restos' then update public.aamix_rewards_state set restos=restos+amount where user_id=uid;
      elsif kind='normal_pack' then update public.aamix_rewards_state set normal_packs=normal_packs+amount where user_id=uid;
      else update public.aamix_rewards_state set packs=packs+amount where user_id=uid; end if;
    else already:=true; end if;
  end if;
  return public.aamix_inventory()||jsonb_build_object('already_claimed',already,'mission_id',p_mission_id,
    'reward_kind',kind,'reward_amount',amount,'reward_packs',case when kind='tc_pack' then amount else 0 end);
end $$;
-- Route the old endpoint to the current daily reward. It cannot mint extra TC packs.
create or replace function aamix_private.claim_daily_mission() returns jsonb
language sql security definer set search_path='' as $$ select aamix_private.claim_mission('play_one'); $$;

create function aamix_private.draw_normal_card() returns jsonb
language plpgsql security definer set search_path='' as $$
declare selected text;
begin
  perform aamix_private.reward_user();
  select code into strict selected from aamix_private.reward_catalog
    where not is_promotional and card_class<>'Recurso' and special_weight=0 order by random() limit 1;
  return jsonb_build_array(selected);
end $$;
revoke all on function aamix_private.draw_normal_card() from public,anon,authenticated;

create function aamix_private.open_pack_kind(p_request_id uuid,p_kind text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); opening public.aamix_pack_openings%rowtype; inventory jsonb;
begin
  if p_request_id is null then raise exception 'Opening request UUID required' using errcode='22023'; end if;
  if p_kind is null or p_kind not in('tc','normal_card') then raise exception 'Invalid pack kind' using errcode='22023'; end if;
  select o.* into opening from public.aamix_pack_requests r join public.aamix_pack_openings o on o.opening_id=r.opening_id
    where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
  if not found then
    -- One shared pending animation across both kinds. Resuming never spends again.
    select * into opening from public.aamix_pack_openings where user_id=uid and revealed_at is null;
    if not found then
      if p_kind='tc' then
        update public.aamix_rewards_state set packs=packs-1 where user_id=uid and packs>0;
      else
        update public.aamix_rewards_state set normal_packs=normal_packs-1 where user_id=uid and normal_packs>0;
      end if;
      if not found then raise exception 'AAMIX_NO_PACKS' using errcode='22023'; end if;
      insert into public.aamix_pack_openings(user_id,request_id,kind,cards,rules_version)
        values(uid,p_request_id,p_kind,case when p_kind='tc' then aamix_private.draw_pack() else aamix_private.draw_normal_card() end,
          case when p_kind='tc' then '0.10.1' else '0.16.0' end) returning * into opening;
      insert into public.aamix_collection(user_id,code,quantity)
        select uid,code,count(*)::integer from jsonb_array_elements_text(opening.cards) as card(code) group by code order by code
        on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    end if;
  end if;
  insert into public.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict(user_id,request_id) do nothing;
  inventory:=public.aamix_inventory();
  return inventory||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,
    'cards',opening.cards,'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end $$;
revoke all on function aamix_private.open_pack_kind(uuid,text) from public,anon,authenticated;
create or replace function aamix_private.open_pack(p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select aamix_private.open_pack_kind(p_request_id,'tc'); $$;
create function aamix_private.open_normal_pack(p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select aamix_private.open_pack_kind(p_request_id,'normal_card'); $$;
create function public.aamix_open_normal_pack(p_request_id uuid) returns jsonb
language sql security invoker set search_path='' as $$ select aamix_private.open_normal_pack(p_request_id); $$;

revoke all on function aamix_private.claim_restos_welcome(),aamix_private.purchase_card(uuid,text),aamix_private.open_normal_pack(uuid),
  aamix_private.missions_status(),aamix_private.claim_mission(text),aamix_private.claim_daily_mission(),aamix_private.open_pack(uuid),
  public.aamix_inventory(),public.aamix_claim_restos_welcome(),public.aamix_purchase_card(uuid,text),public.aamix_open_normal_pack(uuid)
  from public,anon,authenticated;
grant execute on function aamix_private.claim_restos_welcome(),aamix_private.purchase_card(uuid,text),aamix_private.open_normal_pack(uuid),
  aamix_private.missions_status(),aamix_private.claim_mission(text),aamix_private.claim_daily_mission(),aamix_private.open_pack(uuid),
  public.aamix_inventory(),public.aamix_claim_restos_welcome(),public.aamix_purchase_card(uuid,text),public.aamix_open_normal_pack(uuid)
  to authenticated;
notify pgrst,'reload schema';
