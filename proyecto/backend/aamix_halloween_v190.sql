-- AAMIX Online v1.1 / internal 1.9.0. Official production promotion.
-- No player/test data copied, no resets, no bootstrap/test fixtures.
set local check_function_bodies=off;
alter table public.aamix_match_receipts add column event_battle boolean not null default false;
alter table aamix_private.mp_rooms add column host_rematch boolean not null default false,add column guest_rematch boolean not null default false,add column host_rematch_ready boolean not null default false,add column guest_rematch_ready boolean not null default false,add column rematch_cancelled boolean not null default false,add column rematch_room uuid,add column host_next_deck jsonb,add column guest_next_deck jsonb;
create table aamix_private.hw_wallet(user_id uuid primary key references auth.users(id) on delete cascade,halloween_packs integer not null default 0 check(halloween_packs>=0),friend_added boolean not null default false,traded boolean not null default false);
create table aamix_private.hw_mp_rewards(user_id uuid not null references auth.users(id) on delete cascade,match_id uuid not null references public.aamix_match_receipts(match_id),primary key(user_id,match_id));
create table aamix_private.mp_rematch_requests(user_id uuid not null references auth.users(id) on delete cascade,request_id uuid not null,payload jsonb not null,primary key(user_id,request_id));
do $$declare t text;begin foreach t in array array['hw_wallet','hw_mp_rewards','mp_rematch_requests'] loop execute format('alter table aamix_private.%I enable row level security',t);execute format('revoke all on aamix_private.%I from public,anon,authenticated',t);execute format('create policy server_only on aamix_private.%I for all to anon,authenticated using(false) with check(false)',t);end loop;end$$;
alter table public.aamix_pack_openings add column pack_count integer not null default 1 check(pack_count between 1 and 10000);
alter table public.aamix_pack_openings drop constraint aamix_opening_new_indices,drop constraint aamix_pack_openings_kind_check,drop constraint aamix_pack_openings_shape;
alter table public.aamix_pack_openings add constraint aamix_opening_new_indices check(new_card_indices is not null and array_position(new_card_indices,null) is null and 0<=all(new_card_indices) and jsonb_array_length(cards)>all(new_card_indices)),add constraint aamix_pack_openings_kind_check check(kind in('tc','normal_card','halloween')),add constraint aamix_pack_openings_shape check(jsonb_typeof(cards)='array' and jsonb_array_length(cards)=pack_count*case when kind='tc' then 5 else 1 end);
insert into aamix_private.catalog_codes(code) values('H01'),('H02'),('H03'),('H04'),('H05');
insert into aamix_private.reward_catalog(code,name,card_class,special_weight,is_promotional,is_singular) select h.code,r.name,r.card_class,r.special_weight,false,r.is_singular from(values('H01','0104'),('H02','0130'),('H03','0127'),('H04','0102'),('H05','0103'))h(code,base) join aamix_private.reward_catalog r on r.code=h.base;


CREATE OR REPLACE FUNCTION aamix_private.canonical_card(code text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$select case code when 'H01' then '0104' when 'H02' then '0130' when 'H03' then '0127' when 'H04' then '0102' when 'H05' then '0103' else code end$function$;

revoke all on function aamix_private.canonical_card(code text) from public,anon,authenticated;

grant execute on function aamix_private.canonical_card(code text) to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.custom_cards(p_uid uuid, p_cards jsonb, p_draft boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare e jsonb; code_value text; amount integer; owned integer; c aamix_private.reward_catalog%rowtype;

  total integer:=0; resources integer:=0; seen text[]:='{}'; normalized jsonb:='[]'; families jsonb:='{}'; family text; family_amount integer;

begin

  if p_uid is distinct from auth.uid() or p_uid is null then raise exception 'Authentication required' using errcode='28000'; end if;

  if p_draft is null or p_cards is null or jsonb_typeof(p_cards)<>'array' then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;

  if jsonb_array_length(p_cards)>64 or octet_length(p_cards::text)>8192 then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;

  for e in select value from jsonb_array_elements(p_cards) loop

    if jsonb_typeof(e)<>'object' then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;

    if (select count(*) from jsonb_object_keys(e))<>2 or not(e ? 'codigo' and e ? 'cantidad')

      or jsonb_typeof(e->'codigo')<>'string' or jsonb_typeof(e->'cantidad')<>'number'

      or coalesce(e->>'cantidad','')!~'^[1-9][0-9]?$' then raise exception 'AAMIX_INVALID_DECK' using errcode='22023'; end if;

    code_value:=e->>'codigo'; amount:=(e->>'cantidad')::integer;

    if code_value=any(seen) then raise exception 'AAMIX_DUPLICATE_DECK_CARD' using errcode='22023'; end if;

    seen:=array_append(seen,code_value);

    select * into c from aamix_private.reward_catalog where code=code_value;

    if not found then raise exception 'AAMIX_UNKNOWN_CARD' using errcode='22023'; end if;

    family:=aamix_private.canonical_card(code_value); family_amount:=coalesce((families->>family)::integer,0)+amount; families:=families||jsonb_build_object(family,family_amount);
    if c.card_class<>'Recurso' and family_amount>(case when c.is_singular then 1 else 3 end) then raise exception 'AAMIX_DECK_COPY_LIMIT' using errcode='22023'; end if;

    select quantity into owned from public.aamix_collection where user_id=p_uid and code=code_value;

    if amount>coalesce(owned,0) then raise exception 'AAMIX_DECK_UNOWNED_COPIES' using errcode='22023'; end if;

    total:=total+amount;

    if total>40 then raise exception 'AAMIX_DECK_TOO_LARGE' using errcode='22023'; end if;

    if code_value='0100' then resources:=amount; end if;

    normalized:=normalized||jsonb_build_array(jsonb_build_object('codigo',code_value,'cantidad',amount));

  end loop;

  -- Playability size rule is deliberately centralized here; all newly saved decks require a Resource, including drafts.

  if not p_draft and (total<>40) then raise exception 'AAMIX_DECK_SIZE' using errcode='22023'; end if;

  if resources<1 then raise exception 'AAMIX_DECK_INITIAL_RESOURCE' using errcode='22023'; end if;

  return coalesce((select jsonb_agg(sorted.card order by sorted.card->>'codigo') from jsonb_array_elements(normalized) as sorted(card)),'[]'::jsonb);

end $function$;

revoke all on function aamix_private.custom_cards(p_uid uuid, p_cards jsonb, p_draft boolean) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.check_collection_v170(p_uid uuid, p_code text, p_quantity integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare d record;

begin

 if p_quantity>=10 then

  for d in select id from aamix_private.milestone_definitions_v170 where not secret and card_code=p_code loop

   perform aamix_private.complete_milestone_v170(p_uid,d.id);

  end loop;

 end if;

 if exists(select 1 from aamix_private.reward_catalog where code=p_code and not is_promotional)

  and not exists(select 1 from aamix_private.reward_catalog c where not c.is_promotional and c.code not like 'H%' and not exists(

   select 1 from public.aamix_collection o where o.user_id=p_uid and o.code=c.code and o.quantity>0)) then

  perform aamix_private.complete_milestone_v170(p_uid,'collect_all_standard');

 end if;

end $function$;

revoke all on function aamix_private.check_collection_v170(p_uid uuid, p_code text, p_quantity integer) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.avatar_allowed_v170(p_uid uuid, p_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$

 select exists(select 1 from aamix_private.reward_catalog c where c.code=p_code and c.card_class='Aliado' and c.code not like 'H%'

 and ((not c.is_promotional and c.code not in('0112','0113','0114','0126')) or (c.code in('0112','0113','0114','0126','01a','01b') and exists(select 1 from aamix_private.avatar_unlocks_v170 u where u.user_id=p_uid and u.code=p_code))))

$function$;

revoke all on function aamix_private.avatar_allowed_v170(p_uid uuid, p_code text) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.draw_pack()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare codes jsonb := '[]'::jsonb; selected text; ticket double precision; slot integer;

begin

  perform aamix_private.reward_user();

  select code into strict selected from aamix_private.reward_catalog

    where not is_promotional and code not like 'H%' and card_class='Recurso' order by random() limit 1;

  codes := codes || jsonb_build_array(selected);

  for slot in 2..5 loop

    if slot=5 and random()<0.30 then

      ticket := random()*100;

      select code into strict selected from (

        select code,sum(special_weight) over(order by code rows unbounded preceding) as cumulative

        from aamix_private.reward_catalog where not is_promotional and code not like 'H%' and special_weight>0

      ) weighted where cumulative>ticket order by cumulative limit 1;

    else

      select code into strict selected from aamix_private.reward_catalog

        where not is_promotional and code not like 'H%' and card_class<>'Recurso' and special_weight=0 order by random() limit 1;

    end if;

    codes := codes || jsonb_build_array(selected);

  end loop;

  if codes ?| array['01a','01b','01c','01d','01e','01f'] then

    raise exception 'Promotional cards are forbidden in packs' using errcode='23514';

  end if;

  return codes;

end $function$;

revoke all on function aamix_private.draw_pack() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.draw_normal_card()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare selected text;
begin
  perform aamix_private.reward_user();
  select code into strict selected from aamix_private.reward_catalog
    where not is_promotional and code not like 'H%' and card_class<>'Recurso' and special_weight=0 order by random() limit 1;
  return jsonb_build_array(selected);
end $function$;

revoke all on function aamix_private.draw_normal_card() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.shop_catalog()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform aamix_private.reward_user();
  return coalesce((select jsonb_agg(jsonb_build_object('code',code,'price',
    case when code in('0103','0105','0115','0119') then 500 else 150 end) order by code)
    from aamix_private.reward_catalog where not is_promotional and code not like 'H%' and card_class<>'Recurso'),'[]'::jsonb);
end $function$;

revoke all on function aamix_private.shop_catalog() from public,anon,authenticated;

grant execute on function aamix_private.shop_catalog() to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.purchase_card(p_request_id uuid, p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      from aamix_private.reward_catalog where code=p_code and not is_promotional and code not like 'H%' and card_class<>'Recurso';
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
end $function$;

revoke all on function aamix_private.purchase_card(p_request_id uuid, p_code text) from public,anon,authenticated;

grant execute on function aamix_private.purchase_card(p_request_id uuid, p_code text) to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.open_pack_kind(p_request_id uuid, p_kind text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      -- Compute against pre-award quantities. Only the first duplicate in this
      -- opening is new; the result persists across retries and later logins.
      update public.aamix_pack_openings set new_card_indices=coalesce((
        select array_agg((c.ord-1)::integer order by c.ord)
        from jsonb_array_elements_text(opening.cards) with ordinality c(code,ord)
        where not exists(select 1 from public.aamix_collection owned where owned.user_id=uid and owned.code=c.code and owned.quantity>0)
          and c.ord=(select min(x.ord) from jsonb_array_elements_text(opening.cards) with ordinality x(code,ord) where x.code=c.code)
      ),'{}'::integer[]) where opening_id=opening.opening_id returning * into opening;
      insert into public.aamix_collection(user_id,code,quantity)
        select uid,code,count(*)::integer from jsonb_array_elements_text(opening.cards) as card(code) group by code order by code
        on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
    end if;
  end if;
  insert into public.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict(user_id,request_id) do nothing;
  inventory:=public.aamix_inventory();
  return inventory||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,'pack_count',opening.pack_count,
    'cards',opening.cards,'new_card_indices',to_jsonb(opening.new_card_indices),'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end $function$;

revoke all on function aamix_private.open_pack_kind(p_request_id uuid, p_kind text) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.open_halloween_pack(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare uid uuid:=aamix_private.lock_rewards();opening public.aamix_pack_openings%rowtype;ticket integer;picked_code text;first_copy boolean;
begin
 if p_request_id is null then raise exception 'Opening request UUID required' using errcode='22023';end if;
 select o.* into opening from public.aamix_pack_requests r join public.aamix_pack_openings o on o.opening_id=r.opening_id where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
 if not found then
  select * into opening from public.aamix_pack_openings where user_id=uid and revealed_at is null;
  if not found then
   update aamix_private.hw_wallet set halloween_packs=halloween_packs-1 where user_id=uid and halloween_packs>0;
   if not found then raise exception 'AAMIX_NO_PACKS' using errcode='22023';end if;
   ticket:=floor(random()*10000)::integer;
   picked_code:=case when ticket>=9500 then 'H05' else 'H0'||(ticket/2375+1)::text end;
   first_copy:=not exists(select 1 from public.aamix_collection c where c.user_id=uid and c.code=picked_code and quantity>0);
   insert into public.aamix_pack_openings(user_id,request_id,kind,cards,rules_version,new_card_indices)
    values(uid,p_request_id,'halloween',jsonb_build_array(picked_code),'1.9',case when first_copy then array[0] else '{}'::integer[] end) returning * into opening;
   insert into public.aamix_collection(user_id,code,quantity) values(uid,picked_code,1) on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+1;
  end if;
 end if;
 insert into public.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict do nothing;
 return public.aamix_inventory()||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,'pack_count',opening.pack_count,'cards',opening.cards,'new_card_indices',to_jsonb(opening.new_card_indices),'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end $function$;

revoke all on function aamix_private.open_halloween_pack(p_request_id uuid) from public,anon,authenticated;

grant execute on function aamix_private.open_halloween_pack(p_request_id uuid) to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.open_pack_bundle(p_request_id uuid, p_kind text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare uid uuid:=aamix_private.lock_rewards();opening public.aamix_pack_openings%rowtype;amount integer;drawn jsonb;indices integer[];
begin
 if p_request_id is null or p_kind is null or p_kind not in('tc','normal_card','halloween') then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 select o.* into opening from public.aamix_pack_requests r join public.aamix_pack_openings o on o.opening_id=r.opening_id where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
 if not found then
  select * into opening from public.aamix_pack_openings where user_id=uid and revealed_at is null;
  if not found then
   if p_kind='halloween' then
    select halloween_packs into amount from aamix_private.hw_wallet where user_id=uid for update;
   else
    select case when p_kind='tc' then packs else normal_packs end into amount from public.aamix_rewards_state where user_id=uid;
   end if;
   if amount is null or amount<=0 then raise exception 'AAMIX_NO_PACKS' using errcode='22023';end if;
   -- Large inventories can be consumed in groups; ordinary balances open all.
   amount:=least(amount,10000);
   select jsonb_agg(c.value order by p.i,c.ordinality) into drawn from generate_series(1,amount)p(i)
    cross join lateral jsonb_array_elements(case when p.i>0 then case p_kind when 'tc' then aamix_private.draw_pack() when 'normal_card' then aamix_private.draw_normal_card() else aamix_private.draw_halloween_card() end else '[]'::jsonb end) with ordinality c(value,ordinality);
   select coalesce(array_agg(first_index order by first_index),'{}'::integer[]) into indices from(
    select distinct on(c.code)c.code,(c.ord-1)::integer first_index from jsonb_array_elements_text(drawn) with ordinality c(code,ord)
    where not exists(select 1 from public.aamix_collection owned where owned.user_id=uid and owned.code=c.code and quantity>0)
    order by c.code,c.ord
   )first_copies;
   if p_kind='halloween' then update aamix_private.hw_wallet set halloween_packs=halloween_packs-amount where user_id=uid;
   elsif p_kind='tc' then update public.aamix_rewards_state set packs=packs-amount where user_id=uid;
   else update public.aamix_rewards_state set normal_packs=normal_packs-amount where user_id=uid;end if;
   insert into public.aamix_pack_openings(user_id,request_id,kind,cards,rules_version,new_card_indices,pack_count)
    values(uid,p_request_id,p_kind,drawn,'1.9-bundle',indices,amount) returning * into opening;
   insert into public.aamix_collection(user_id,code,quantity)
    select uid,code,count(*)::integer from jsonb_array_elements_text(drawn)c(code) group by code order by code
    on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
  end if;
 end if;
 insert into public.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict do nothing;
 return public.aamix_inventory()||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,'cards',opening.cards,'pack_count',opening.pack_count,'new_card_indices',to_jsonb(opening.new_card_indices),'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end$function$;

revoke all on function aamix_private.open_pack_bundle(p_request_id uuid, p_kind text) from public,anon,authenticated;

grant execute on function aamix_private.open_pack_bundle(p_request_id uuid, p_kind text) to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.draw_halloween_card()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select jsonb_build_array(case when ticket>=9500 then 'H05' else 'H0'||(ticket/2375+1)::text end)
 from(select floor(random()*10000)::integer ticket)s
$function$;

revoke all on function aamix_private.draw_halloween_card() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.halloween_deck()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$select '{
  "id": "halloween",
  "nombre": "Mazo Halloween",
  "portada": "halloween",
  "recurso_inicial": "0100",
  "cartas": [
    {
      "codigo": "0100",
      "cantidad": 17
    },
    {
      "codigo": "H04",
      "cantidad": 3
    },
    {
      "codigo": "0128",
      "cantidad": 3
    },
    {
      "codigo": "H01",
      "cantidad": 3
    },
    {
      "codigo": "H02",
      "cantidad": 1
    },
    {
      "codigo": "H03",
      "cantidad": 1
    },
    {
      "codigo": "01b",
      "cantidad": 1
    },
    {
      "codigo": "0112",
      "cantidad": 2
    },
    {
      "codigo": "0113",
      "cantidad": 2
    },
    {
      "codigo": "H05",
      "cantidad": 1
    },
    {
      "codigo": "0116",
      "cantidad": 2
    },
    {
      "codigo": "0120",
      "cantidad": 2
    },
    {
      "codigo": "0124",
      "cantidad": 2
    }
  ]
}
'::jsonb $function$;

revoke all on function aamix_private.halloween_deck() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.halloween_definition()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ select '{"id": "halloween_2026", "title": "EVENTO HALLOWEEN", "card_code": "H05", "featured_cards": ["H02", "H05"], "start_day": "2026-10-30", "end_day": "2026-11-01", "battle": true, "battle_id": "halloween", "preview": false, "summary": "La festividad del terror se toma AAMIX, encuentra las cinco Cartas Exclusivas del evento y completa las misiones para obtener recompensas. Durante este evento, los ganadores de batallas multijugador recibirán 1 Sobre AAMIX Halloween.", "missions": [{"id": "play_three", "title": "Juega 3 partidas", "target": 3, "metric": "played", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "play_five", "title": "Juega 5 partidas", "target": 5, "metric": "played", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "win_three", "title": "Gana 3 partidas", "target": 3, "metric": "wins", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "trade_one", "title": "Intercambia 1 carta", "target": 1, "metric": "trades", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "friend_one", "title": "Añade 1 Amigo", "target": 1, "metric": "friends", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "event_win_five", "title": "Gana 5 veces la Partida de Evento", "target": 5, "metric": "event_wins", "scope": "event", "reward": {"cards": [{"codigo": "H05", "cantidad": 1}]}}]}'::jsonb $function$;

revoke all on function aamix_private.halloween_definition() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.begin_event_match(p_request_id uuid, p_deck_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare uid uuid:=aamix_private.lock_rewards();receipt public.aamix_match_receipts%rowtype;response jsonb;
begin
 if p_request_id is null then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 select * into receipt from public.aamix_match_receipts where user_id=uid and request_id=p_request_id;
 if found then
  if not receipt.event_battle or receipt.deck_id is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023';end if;
  response:=public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_deck',receipt.player_deck);
 else
  if not exists(select 1 from aamix_private.event_definitions where id='halloween_2026' and (aamix_private.event_clock() at time zone 'America/Santiago')::date between start_day and end_day) then raise exception 'AAMIX_EVENT_INACTIVE' using errcode='22023';end if;
  response:=aamix_private.begin_match(p_request_id,p_deck_id);
  update public.aamix_match_receipts set event_battle=true where match_id=(response->>'match_id')::uuid and user_id=uid;
 end if;
 return response||jsonb_build_object('event_battle',true,'event_opponent',aamix_private.halloween_deck());
end $function$;

revoke all on function aamix_private.begin_event_match(p_request_id uuid, p_deck_id text) from public,anon,authenticated;

grant execute on function aamix_private.begin_event_match(p_request_id uuid, p_deck_id text) to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.begin_match(p_request_id uuid, p_deck_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype; d jsonb;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found then
    if receipt.deck_id<>p_deck_id or receipt.challenge_stage is not null or receipt.online_room_id is not null or receipt.event_battle then raise exception 'Request UUID already used for a different match' using errcode='22023'; end if;
    d:=coalesce(receipt.player_deck,aamix_private.mp_deck(uid,p_deck_id));
  else
    d:=aamix_private.mp_deck(uid,p_deck_id);
    insert into public.aamix_match_receipts(user_id,request_id,deck_id,player_deck) values(uid,p_request_id,p_deck_id,d) returning * into receipt;
  end if;
  return public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result,'challenge_stage',null,'match_deck',d);
end $function$;

revoke all on function aamix_private.begin_match(p_request_id uuid, p_deck_id text) from public,anon,authenticated;

grant execute on function aamix_private.begin_match(p_request_id uuid, p_deck_id text) to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.mp_response(p_room_id uuid, p_uid uuid, p_since integer DEFAULT '-1'::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r aamix_private.mp_rooms%rowtype; s integer; data jsonb;
begin
  select * into strict r from aamix_private.mp_rooms where id=p_room_id;
  s:=case when p_uid=r.host_id then 0 when p_uid=r.guest_id then 1 else -1 end;
  if s=-1 then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  data:=jsonb_build_object('protocol',3,'ruleset_version',r.ruleset_version,'room_version',r.room_version,'confirmed',jsonb_build_array(r.host_confirmed,r.guest_confirmed),'room_id',r.id,'code',r.code,'status',r.status,'slot',s,'revision',r.revision,
    'actor_slot',r.actor_slot,'winner',r.winner,'expires_at',r.expires_at,'last_error',r.last_error,
    'finish_reason',r.finish_reason,'opponent_online',case when s=0 then r.guest_seen>now()-interval '20 seconds' else r.host_seen>now()-interval '20 seconds' end,
    'players',jsonb_build_array(
      jsonb_build_object('slot',0,'avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=r.host_id),'name',r.host_name,'deck_id',r.host_deck->>'id','deck_name',r.host_deck->>'nombre','cover',r.host_deck->>'portada'),
      case when r.guest_id is null then null else jsonb_build_object('slot',1,'avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=r.guest_id),'name',r.guest_name,'deck_id',r.guest_deck->>'id','deck_name',r.guest_deck->>'nombre','cover',r.guest_deck->>'portada') end));
  if s=0 then
    data:=data||jsonb_build_object('commands',coalesce((
      select jsonb_agg(jsonb_build_object('request_id',c.request_id,'slot',c.slot,'method',c.method,'args',c.args,'revision',c.revision) order by c.created_at)
      from aamix_private.mp_commands c where c.room_id=r.id and c.status='pending'),'[]'::jsonb));
    if r.revision=0 or p_since=-1 then
      data:=data||jsonb_build_object('host_deck',r.host_deck,'guest_deck',r.guest_deck);
      data:=jsonb_set(data,'{players,0,deck}',r.host_deck);
    if r.guest_id is not null then data:=jsonb_set(data,'{players,1,deck}',r.guest_deck); end if;
    end if;
  end if;
  if p_since<>r.revision then data:=data||jsonb_build_object('state',case s when 0 then r.host_state else r.guest_view end); end if;
  return data||jsonb_build_object('rematch',jsonb_build_object('requested',jsonb_build_array(r.host_rematch,r.guest_rematch),'ready',jsonb_build_array(r.host_rematch_ready,r.guest_rematch_ready),'cancelled',r.rematch_cancelled,'next_room_id',r.rematch_room,'deck_id',case s when 0 then r.host_next_deck->>'id' else r.guest_next_deck->>'id' end));
end $function$;

revoke all on function aamix_private.mp_response(p_room_id uuid, p_uid uuid, p_since integer) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.mp_notify_room()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

begin

  if tg_op='UPDATE' and new.revision=old.revision and new.status=old.status

    and new.guest_id is not distinct from old.guest_id

    and new.host_confirmed=old.host_confirmed and new.guest_confirmed=old.guest_confirmed and new.room_version=old.room_version then return null; end if;

  perform realtime.send(aamix_private.mp_response(new.id,new.host_id,-1),'room','aamix:user:'||new.host_id::text,true);

  if new.guest_id is not null then

    perform realtime.send(aamix_private.mp_response(new.id,new.guest_id,-1),'room','aamix:user:'||new.guest_id::text,true);

  end if;

  return null;

end $function$;

revoke all on function aamix_private.mp_notify_room() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.rematch_deck_current(p_uid uuid, p_deck jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare cards jsonb;is_draft boolean;
begin
 select d.cards,d.draft into cards,is_draft from public.aamix_owned_decks d where user_id=p_uid and deck_id=p_deck->>'id' for share;
 if not found then select d.cards,d.draft into cards,is_draft from public.aamix_custom_decks d where user_id=p_uid and deck_id=p_deck->>'id' for share;end if;
 if cards is null or is_draft or cards is distinct from p_deck->'cartas' then return false;end if;
 perform 1 from public.aamix_collection where user_id=p_uid for share;
 return not exists(select 1 from jsonb_array_elements(cards)e where coalesce((select quantity from public.aamix_collection where user_id=p_uid and code=e->>'codigo'),0)<(e->>'cantidad')::integer);
end$function$;

revoke all on function aamix_private.rematch_deck_current(p_uid uuid, p_deck jsonb) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION aamix_private.rematch_action(p_room_id uuid, p_request_id uuid, p_action text, p_deck_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare uid uuid:=aamix_private.reward_user();r aamix_private.mp_rooms%rowtype;
 next_room aamix_private.mp_rooms%rowtype;payload jsonb;previous jsonb;d jsonb;c text;s integer;
begin
 if p_request_id is null or p_action is null or p_action not in('request','choose','ready','cancel') then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 -- Same lock ordering as room creation. This lock is exclusive to the preview.
 perform pg_advisory_xact_lock(170017,1);
 select * into r from aamix_private.mp_rooms where id=p_room_id for update;
 if not found or uid not in(r.host_id,coalesce(r.guest_id,r.host_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501';end if;
 s:=case when uid=r.host_id then 0 else 1 end;
 payload:=jsonb_build_object('room',p_room_id,'action',p_action,'deck',p_deck_id);
 select q.payload into previous from aamix_private.mp_rematch_requests q where q.user_id=uid and q.request_id=p_request_id;
 if found then
  if previous<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023';end if;
  return aamix_private.mp_response(r.id,uid);
 end if;
 if r.status<>'finished' or r.guest_id is null then raise exception 'AAMIX_ROOM_NOT_FINISHED' using errcode='22023';end if;
 if p_action='cancel' then
  if r.rematch_room is not null then
   select * into next_room from aamix_private.mp_rooms where id=r.rematch_room for update;
   if next_room.status in('waiting','ready','playing') then perform aamix_private.mp_leave(next_room.id);end if;
  end if;
  update aamix_private.mp_rooms set rematch_cancelled=true,host_rematch_ready=false,guest_rematch_ready=false,room_version=room_version+1 where id=r.id;
 else
  if r.rematch_cancelled then raise exception 'AAMIX_REMATCH_CANCELLED' using errcode='22023';end if;
  if r.rematch_room is not null then raise exception 'AAMIX_REMATCH_STARTED' using errcode='22023';end if;
  if exists(select 1 from aamix_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023';end if;
  if p_action in('request','choose') then
   d:=aamix_private.mp_deck(uid,p_deck_id);
   if s=0 then
    update aamix_private.mp_rooms set host_rematch=true,host_next_deck=d,host_rematch_ready=false,room_version=room_version+1 where id=r.id;
   else
    update aamix_private.mp_rooms set guest_rematch=true,guest_next_deck=d,guest_rematch_ready=false,room_version=room_version+1 where id=r.id;
   end if;
  else
   if not(r.host_rematch and r.guest_rematch) then raise exception 'AAMIX_REMATCH_WAITING' using errcode='22023';end if;
   -- Validate ownership and playability again when confirming.
   d:=aamix_private.mp_deck(uid,case s when 0 then r.host_next_deck->>'id' else r.guest_next_deck->>'id' end);
   if s=0 then update aamix_private.mp_rooms set host_next_deck=d,host_rematch_ready=true,room_version=room_version+1 where id=r.id;
   else update aamix_private.mp_rooms set guest_next_deck=d,guest_rematch_ready=true,room_version=room_version+1 where id=r.id;end if;
  end if;
  select * into r from aamix_private.mp_rooms where id=p_room_id;
  if r.host_rematch and r.guest_rematch and r.host_rematch_ready and r.guest_rematch_ready then
   if (select count(*) from aamix_private.mp_rooms where status in('waiting','ready','playing'))>=8 then raise exception 'AAMIX_ROOMS_FULL' using errcode='53300';end if;
   if exists(select 1 from aamix_private.mp_members where user_id in(r.host_id,r.guest_id)) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023';end if;
   if not aamix_private.rematch_deck_current(r.host_id,r.host_next_deck) or not aamix_private.rematch_deck_current(r.guest_id,r.guest_next_deck) then raise exception 'AAMIX_DECK_CHANGED' using errcode='22023';end if;
   loop
    c:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from aamix_private.mp_rooms where code=c);
   end loop;
   insert into aamix_private.mp_rooms(code,host_id,guest_id,create_request,join_request,host_deck,guest_deck,host_name,guest_name,status,host_confirmed,guest_confirmed,guest_seen,ruleset_version)
    values(c,r.host_id,r.guest_id,gen_random_uuid(),gen_random_uuid(),r.host_next_deck,r.guest_next_deck,r.host_name,r.guest_name,'ready',true,true,now(),r.ruleset_version) returning * into next_room;
   insert into aamix_private.mp_members(user_id,room_id) values(r.host_id,next_room.id),(r.guest_id,next_room.id);
   update aamix_private.mp_rooms set rematch_room=next_room.id,room_version=room_version+1 where id=r.id;
  end if;
 end if;
 insert into aamix_private.mp_rematch_requests(user_id,request_id,payload) values(uid,p_request_id,payload);
 return aamix_private.mp_response(r.id,uid);
end $function$;

revoke all on function aamix_private.rematch_action(p_room_id uuid, p_request_id uuid, p_action text, p_deck_id text) from public,anon,authenticated;

grant execute on function aamix_private.rematch_action(p_room_id uuid, p_request_id uuid, p_action text, p_deck_id text) to authenticated;

CREATE OR REPLACE FUNCTION public.aamix_open_halloween_pack(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select aamix_private.open_halloween_pack(p_request_id)$function$;

revoke all on function public.aamix_open_halloween_pack(p_request_id uuid) from public,anon,authenticated;

grant execute on function public.aamix_open_halloween_pack(p_request_id uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.aamix_open_all_packs(p_request_id uuid, p_kind text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select aamix_private.open_pack_bundle(p_request_id,p_kind)$function$;

revoke all on function public.aamix_open_all_packs(p_request_id uuid, p_kind text) from public,anon,authenticated;

grant execute on function public.aamix_open_all_packs(p_request_id uuid, p_kind text) to authenticated;

CREATE OR REPLACE FUNCTION public.aamix_begin_event_match(p_request_id uuid, p_deck_id text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select aamix_private.begin_event_match(p_request_id,p_deck_id)$function$;

revoke all on function public.aamix_begin_event_match(p_request_id uuid, p_deck_id text) from public,anon,authenticated;

grant execute on function public.aamix_begin_event_match(p_request_id uuid, p_deck_id text) to authenticated;

CREATE OR REPLACE FUNCTION public.aamix_mp_rematch(p_room_id uuid, p_request_id uuid, p_action text, p_deck_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$select aamix_private.rematch_action(p_room_id,p_request_id,p_action,p_deck_id)$function$;

revoke all on function public.aamix_mp_rematch(p_room_id uuid, p_request_id uuid, p_action text, p_deck_id text) from public,anon,authenticated;

grant execute on function public.aamix_mp_rematch(p_room_id uuid, p_request_id uuid, p_action text, p_deck_id text) to authenticated;

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
    'decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'draft',draft,'editable',editable,'revision',revision) order by obtained_at,deck_id) from public.aamix_owned_decks where user_id=uid),'[]'::jsonb),
    'custom_decks',coalesce((select jsonb_agg(jsonb_build_object('id',deck_id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards,'custom',true,'draft',draft,'revision',revision) order by created_at,deck_id) from public.aamix_custom_decks where user_id=uid),'[]'::jsonb),
    'profile',jsonb_build_object('avatar_code',(select avatar_code from public.aamix_rewards_state where user_id=uid)),
    'packs',coalesce((select packs from public.aamix_rewards_state where user_id=uid),0),
    'mission',(missions->0)-'scope','missions',missions,'challenges',aamix_private.challenges_status(),
    'pending_opening',(select jsonb_build_object('opening_id',opening_id,'kind',kind,'pack_count',pack_count,'cards',cards,'new_card_indices',to_jsonb(new_card_indices),'opened_at',opened_at,'revealed_at',revealed_at) from public.aamix_pack_openings where user_id=uid and revealed_at is null),
    'redeemed_codes',coalesce((select jsonb_agg(gift_code order by gift_code) from public.aamix_code_redemptions where user_id=uid),'[]'::jsonb))||aamix_private.deck_designs_inventory()||aamix_private.events_inventory()||aamix_private.cosmetics_inventory_v170();
end $function$;

revoke all on function public.aamix_inventory() from public,anon,authenticated;

grant execute on function public.aamix_inventory() to authenticated;

CREATE OR REPLACE FUNCTION aamix_private.mp_create_room_ruleset(p_request_id uuid, p_deck_id text, p_ruleset_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; c text; n text;
begin
  if p_ruleset_version is null or p_ruleset_version not in('1.2','1.3','1.9') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if p_request_id is null then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(170017,1);
  perform aamix_private.mp_cleanup();
  select * into r from aamix_private.mp_rooms where host_id=uid and create_request=p_request_id;
  if found then
    if r.ruleset_version<>p_ruleset_version then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
    if r.host_deck->>'id' is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid);
  end if;
  if exists(select 1 from aamix_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023'; end if;
  if (select count(*) from aamix_private.mp_rooms where status in('waiting','ready','playing'))>=8 then raise exception 'AAMIX_ROOMS_FULL' using errcode='53300'; end if;
  d:=aamix_private.mp_deck(uid,p_deck_id);
  if p_ruleset_version<>'1.9' and exists(select 1 from jsonb_array_elements(d->'cartas')c where c->>'codigo' like 'H%') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023';end if;
  select left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),'Jugador'),24) into n from auth.users where id=uid;
  loop
    c:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from aamix_private.mp_rooms where code=c);
  end loop;
  insert into aamix_private.mp_rooms(code,host_id,create_request,host_deck,host_name,ruleset_version) values(c,uid,p_request_id,d,n,p_ruleset_version) returning * into r;
  insert into aamix_private.mp_members(user_id,room_id) values(uid,r.id);
  return aamix_private.mp_response(r.id,uid);
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.mp_join_room_ruleset(p_code text, p_deck_id text, p_request_id uuid, p_ruleset_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype; d jsonb; n text;
begin
  if p_ruleset_version is null or p_ruleset_version not in('1.2','1.3','1.9') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if p_request_id is null or p_code is null or upper(btrim(p_code))!~'^[0-9A-F]{8}$' then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(170017,1);
  perform aamix_private.mp_cleanup();
  select * into r from aamix_private.mp_rooms where code=upper(btrim(p_code)) for update;
  if not found then raise exception 'AAMIX_INVALID_ROOM' using errcode='22023'; end if;
  -- Validate compatibility before replay, deck resolution or any membership mutation.
  if r.invited_user is not null and r.invited_user<>uid then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  if r.ruleset_version<>p_ruleset_version then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
  if r.guest_id=uid and r.join_request=p_request_id then
    if r.guest_deck->>'id' is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023'; end if;
    return aamix_private.mp_response(r.id,uid);
  end if;
  if r.status<>'waiting' or r.guest_id is not null or r.host_id=uid then raise exception 'AAMIX_ROOM_UNAVAILABLE' using errcode='22023'; end if;
  if exists(select 1 from aamix_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023'; end if;
  d:=aamix_private.mp_deck(uid,p_deck_id);
  if p_ruleset_version<>'1.9' and exists(select 1 from jsonb_array_elements(d->'cartas')c where c->>'codigo' like 'H%') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023';end if;
  select left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),'Jugador'),24) into n from auth.users where id=uid;
  update aamix_private.mp_rooms set guest_id=uid,guest_deck=d,guest_name=n,join_request=p_request_id,status='ready',guest_seen=now() where id=r.id;
  insert into aamix_private.mp_members(user_id,room_id) values(uid,r.id);
  return aamix_private.mp_response(r.id,uid);
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.mp_active_ruleset(p_ruleset_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user(); r aamix_private.mp_rooms%rowtype;
begin
  select room.* into r from aamix_private.mp_rooms room join aamix_private.mp_members member on member.room_id=room.id where member.user_id=uid;
  if not found then return jsonb_build_object('room_id',null); end if;
  if r.ruleset_version is distinct from p_ruleset_version then
    if p_ruleset_version not in('1.3','1.9') then raise exception 'AAMIX_RULESET_MISMATCH' using errcode='22023'; end if;
    -- A newer client may offer closing an old room without restoring its rules engine.
    return jsonb_build_object('protocol',3,'room_id',r.id,'code',r.code,'status',r.status,'ruleset_version',r.ruleset_version,
      'incompatible',true,'revision',r.revision,'room_version',r.room_version,'slot',case when uid=r.host_id then 0 else 1 end);
  end if;
  return aamix_private.mp_poll(r.id,-1);
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.duel_create(p_peer uuid, p_deck text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.social_lock_pair(p_peer);payload jsonb:=jsonb_build_object('peer',p_peer,'deck',p_deck);replay jsonb; room jsonb;invitation uuid;
begin
 replay:=aamix_private.social_replay(p_request_id,'duel_create',payload);
 if replay is not null then return aamix_private.social_inventory()||jsonb_build_object('room',aamix_private.mp_response((replay->>'room_id')::uuid,uid));end if;
 if not aamix_private.social_is_friend(uid,p_peer) then raise exception 'AAMIX_NOT_FRIENDS' using errcode='42501';end if;
 room:=aamix_private.mp_create_room_ruleset(p_request_id,p_deck,'1.9');
 update aamix_private.mp_rooms set invited_user=p_peer where id=(room->>'room_id')::uuid;
 insert into aamix_private.friend_duels(host_id,guest_id,room_id) values(uid,p_peer,(room->>'room_id')::uuid) returning id into invitation;
 insert into aamix_private.social_requests values(uid,p_request_id,'duel_create',payload,jsonb_build_object('room_id',room->>'room_id'),now());
 return aamix_private.social_inventory()||jsonb_build_object('room',room);
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.duel_respond(p_invite uuid, p_accept boolean, p_deck text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user();d aamix_private.friend_duels%rowtype;r aamix_private.mp_rooms%rowtype;payload jsonb;replay jsonb;room jsonb;
begin
 select * into d from aamix_private.friend_duels where id=p_invite and guest_id=uid;
 if not found then raise exception 'AAMIX_INVITE_UNAVAILABLE' using errcode='42501';end if;
 perform aamix_private.social_lock_pair(d.host_id);payload:=jsonb_build_object('invite',p_invite,'accept',p_accept,'deck',p_deck);replay:=aamix_private.social_replay(p_request_id,'duel_respond',payload);
 if replay is not null then
  return aamix_private.social_inventory()||case when p_accept then jsonb_build_object('room',aamix_private.mp_response(d.room_id,uid)) else '{}'::jsonb end;
 end if;
 select * into strict d from aamix_private.friend_duels where id=p_invite for update;
 if d.status<>'pending' or d.expires_at<=now() or p_accept is null or not aamix_private.social_is_friend(uid,d.host_id) then raise exception 'AAMIX_INVITE_UNAVAILABLE' using errcode='22023';end if;
 select * into strict r from aamix_private.mp_rooms where id=d.room_id;
 if p_accept then room:=aamix_private.mp_join_room_ruleset(r.code,p_deck,p_request_id,r.ruleset_version);
 else
  if r.status='waiting' then perform aamix_private.mp_finish(r.id,-1,'invite_declined');end if;
 end if;
 update aamix_private.friend_duels set status=case when p_accept then 'accepted' else 'declined' end where id=d.id;
 insert into aamix_private.social_requests values(uid,p_request_id,'duel_respond',payload,'{}',now());
 return aamix_private.social_inventory()||case when p_accept then jsonb_build_object('room',room) else '{}'::jsonb end;
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.historical_status_v150()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.reward_user();q record;progress bigint;result jsonb:='[]';
begin
 for q in select * from (values
('play_fifty','Juega 50 partidas',50,'normal_pack',10,null::text),
('win_fifty','Gana 50 partidas',50,'tc_pack',7,null::text),
('win_five_kajido','Gana 5 partidas con un mazo que incluya a Kajido',5,'restos',200,'0105'),
('win_five_flaan','Gana 5 partidas con un mazo que incluya a SoyFlaan',5,'restos',200,'0103'),
('win_five_papito','Gana 5 partidas con un mazo que incluya a Papito',5,'restos',200,'0115')
 ) definitions(id,title,target,kind,amount,card) loop
  select count(*) into progress from public.aamix_match_receipts r where r.user_id=uid and r.finished_at is not null and r.result in('victory','defeat')
  and (q.id='play_fifty' or r.result='victory') and (q.card is null or exists(select 1 from jsonb_array_elements(coalesce(r.player_deck->'cartas','[]')) c where aamix_private.canonical_card(c->>'codigo')=q.card and (c->>'cantidad')::integer>0));
  result:=result||jsonb_build_array(jsonb_build_object('id',q.id,'title',q.title,'scope','lifetime','target',q.target,'progress',least(progress,q.target),'claimed',exists(select 1 from aamix_private.historical_claims_v150 where user_id=uid and mission_id=q.id),'reward_kind',q.kind,'reward_amount',q.amount,'reward_packs',case when q.kind='tc_pack' then q.amount else 0 end));
 end loop;
 return result;
end $function$;

create function aamix_private.halloween_progress() returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_private.reward_user();stamp timestamptz:=aamix_private.event_clock();e aamix_private.event_definitions%rowtype;lo timestamptz;hi timestamptz;earned integer;played integer:=0;wins integer:=0;event_wins integer:=0;friends integer:=0;trades integer:=0;
begin
 insert into aamix_private.hw_wallet(user_id) values(uid) on conflict do nothing;
 perform 1 from aamix_private.hw_wallet where user_id=uid for update;
 select * into strict e from aamix_private.event_definitions where id='halloween_2026';
 lo:=e.start_day::timestamp at time zone 'America/Santiago';hi:=(e.end_day+1)::timestamp at time zone 'America/Santiago';
 if stamp>=lo and stamp<hi then
  with granted as(insert into aamix_private.hw_mp_rewards(user_id,match_id)
   select uid,r.match_id from public.aamix_match_receipts r where r.user_id=uid and r.online_room_id is not null and r.result='victory' and r.finished_at>=lo and r.finished_at<hi and r.finished_at<=stamp
   on conflict do nothing returning match_id)select count(*) into earned from granted;
  if earned>0 then update aamix_private.hw_wallet set halloween_packs=halloween_packs+earned where user_id=uid;end if;
 end if;
 select count(*)filter(where result in('victory','defeat')),count(*)filter(where result='victory'),count(*)filter(where result='victory' and event_battle)
 into played,wins,event_wins from public.aamix_match_receipts where user_id=uid and finished_at>=lo and finished_at<hi and finished_at<=stamp;
 select count(*) into friends from aamix_private.friendships where uid in(low_id,high_id) and status='accepted' and updated_at>=lo and updated_at<hi and updated_at<=stamp;
 select count(*) into trades from aamix_private.trade_rooms_v160 where uid in(a_id,b_id) and status='completed' and closed_at>=lo and closed_at<hi and closed_at<=stamp;
 return jsonb_build_object('played',played,'wins',wins,'event_wins',event_wins,'friends',friends,'trades',trades);
end$$;
revoke all on function aamix_private.halloween_progress() from public,anon,authenticated;


update aamix_private.event_definitions set title='EVENTO HALLOWEEN',card_code='H05',start_day='2026-10-30',end_day='2026-11-01',summary=$summary$La festividad del terror se toma AAMIX, encuentra las cinco Cartas Exclusivas del evento y completa las misiones para obtener recompensas. Durante este evento, los ganadores de batallas multijugador recibirán 1 Sobre AAMIX Halloween.$summary$,missions='[{"id": "play_three", "title": "Juega 3 partidas", "target": 3, "metric": "played", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "play_five", "title": "Juega 5 partidas", "target": 5, "metric": "played", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "win_three", "title": "Gana 3 partidas", "target": 3, "metric": "wins", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "trade_one", "title": "Intercambia 1 carta", "target": 1, "metric": "trades", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "friend_one", "title": "Añade 1 Amigo", "target": 1, "metric": "friends", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "event_win_five", "title": "Gana 5 veces la Partida de Evento", "target": 5, "metric": "event_wins", "scope": "event", "reward": {"cards": [{"codigo": "H05", "cantidad": 1}]}}]'::jsonb where id='halloween_2026';

update aamix_private.gift_code_rewards set avatar_code='01b',reward_name='1 Bigotes y su foto de perfil' where gift_code='GATONEGRO';

CREATE OR REPLACE FUNCTION aamix_private.events_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); stamp timestamptz:=aamix_private.event_clock();
 today date:=(stamp at time zone 'America/Santiago')::date; e record; m jsonb;
 states jsonb; active_events jsonb:='[]'; progress bigint; period text; next_at timestamptz; hw jsonb;
begin
 if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
 hw:=aamix_private.halloween_progress();
 next_at:=(today+1)::timestamp at time zone 'America/Santiago';
 select least(next_at,min(boundary)) into next_at from (
  select start_day::timestamp at time zone 'America/Santiago' boundary from aamix_private.event_definitions
  union all select (end_day+1)::timestamp at time zone 'America/Santiago' from aamix_private.event_definitions
 ) dates where boundary>stamp;
 for e in select * from aamix_private.event_definitions where today between start_day and end_day order by start_day,id loop
  states:='[]';
  for m in select value from jsonb_array_elements(e.missions) loop
   period:=case when m->>'scope'='daily' then today::text else 'event' end;
   if e.id='halloween_2026' then
    progress:=coalesce((hw->>(m->>'metric'))::integer,0);
   elsif m->>'metric'='login' then
    select count(*) into progress from aamix_private.event_visits v where v.user_id=uid and v.event_id=e.id and v.day=today;
   else
    select count(*) into progress from public.aamix_match_receipts r
    where r.user_id=uid and r.finished_at>=e.start_day::timestamp at time zone 'America/Santiago'
     and r.finished_at<(e.end_day+1)::timestamp at time zone 'America/Santiago' and r.finished_at<=stamp
     and r.result in('victory','defeat') and (m->>'metric'='played' or r.result='victory')
     and (not(m ? 'deck_id') or r.deck_id=m->>'deck_id')
     and (not(m ? 'required_card') or exists(select 1 from jsonb_array_elements(coalesce(r.player_deck->'cartas','[]')) c
       where aamix_private.canonical_card(c->>'codigo')=m->>'required_card' and (c->>'cantidad')::integer>=1));
   end if;
   states:=states||jsonb_build_array(m||jsonb_build_object('progress',least(progress,(m->>'target')::integer),
    'period_key',period,'claimed',exists(select 1 from aamix_private.event_claims c where c.user_id=uid and c.event_id=e.id and c.mission_id=m->>'id' and c.period_key=period)));
  end loop;
  active_events:=active_events||jsonb_build_array(jsonb_build_object('id',e.id,'title',e.title,'card_code',e.card_code,
   'start_day',e.start_day,'end_day',e.end_day,'summary',e.summary,'missions',states)||case when e.id='halloween_2026' then jsonb_build_object('battle',true,'battle_id','halloween','featured_cards',jsonb_build_array('H02','H05')) else '{}'::jsonb end);
 end loop;
 return jsonb_build_object('events',active_events,'server_day',today,'server_time',extract(epoch from stamp),
  'events_valid_until',extract(epoch from next_at),'events_timezone','America/Santiago','halloween_packs',coalesce((select halloween_packs from aamix_private.hw_wallet where user_id=uid),0));
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.claim_event_mission(p_event_id text, p_mission_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); e jsonb; m jsonb; prize jsonb; granted uuid; period text;
begin
 select value into e from jsonb_array_elements(aamix_private.events_inventory()->'events') where value->>'id'=p_event_id;
 if e is null then raise exception 'AAMIX_EVENT_INACTIVE' using errcode='22023'; end if;
 select value into m from jsonb_array_elements(e->'missions') where value->>'id'=p_mission_id;
 if m is null then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023'; end if;
 period:=m->>'period_key';
 if not (m->>'claimed')::boolean and (m->>'progress')::integer<(m->>'target')::integer then
  raise exception 'AAMIX_MISSION_NOT_READY' using errcode='22023';
 end if;
 prize:=m->'reward';
 insert into aamix_private.event_claims(user_id,event_id,mission_id,period_key,reward)
  values(uid,p_event_id,p_mission_id,period,prize) on conflict do nothing returning user_id into granted;
 if granted is not null then
  update aamix_private.hw_wallet set halloween_packs=halloween_packs+coalesce((prize->>'halloween_packs')::integer,0) where user_id=uid;
  update public.aamix_rewards_state set restos=restos+coalesce((prize->>'restos')::integer,0),
   packs=packs+coalesce((prize->>'packs')::integer,0),normal_packs=normal_packs+coalesce((prize->>'normal_packs')::integer,0) where user_id=uid;
  insert into public.aamix_collection(user_id,code,quantity)
   select uid,c->>'codigo',(c->>'cantidad')::integer from jsonb_array_elements(coalesce(prize->'cards','[]')) c order by c->>'codigo'
   on conflict(user_id,code) do update set quantity=public.aamix_collection.quantity+excluded.quantity;
  if prize ? 'deck_design' then
   insert into aamix_private.event_design_unlocks(user_id,design,event_id) values(uid,prize->>'deck_design',p_event_id) on conflict do nothing;
  end if;
 else
  select reward into prize from aamix_private.event_claims where user_id=uid and event_id=p_event_id and mission_id=p_mission_id and period_key=period;
 end if;
 return public.aamix_inventory()||jsonb_build_object('already_claimed',granted is null,'event_id',p_event_id,'mission_id',p_mission_id,'event_reward',prize);
end $function$;

reset check_function_bodies;
NOTIFY pgrst, 'reload schema';