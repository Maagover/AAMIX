-- Reviewed additive preview migration; fail closed if the official service changed.
do $$begin
 if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='aamix_private' or(n.nspname='public' and p.proname like 'aamix_%'))<>147 then raise exception 'Official schema changed; review the preview again';end if;
 if (select md5(string_agg(pg_get_functiondef(p.oid)||coalesce(p.proacl::text,''),E'\n' order by p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='aamix_private' or(n.nspname='public' and p.proname like 'aamix_%'))<>'b9d40089e50abf626c5a73d6dae15199' then raise exception 'Official functions changed; review the preview again';end if;
end$$;
-- Isolated test schemas. No real collection, balance, room or progress is copied or changed.
create schema aamix_hw01;
create schema aamix_hw01_private;
revoke all on schema aamix_hw01,aamix_hw01_private from public,anon,authenticated;
grant usage on schema aamix_hw01,aamix_hw01_private to authenticated;
set local check_function_bodies=off;
do $clone$
#variable_conflict use_column
declare t record;f record;c record;target_schema text;source text;signature text;
begin
 for t in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where c.relkind='r' and(n.nspname='aamix_private' or(n.nspname='public' and c.relname like 'aamix_%')) loop
  target_schema:=case t.nspname when 'public' then 'aamix_hw01' else 'aamix_hw01_private' end;
  execute format('create table %I.%I(like %I.%I including all)',target_schema,t.relname,t.nspname,t.relname);
  execute format('alter table %I.%I enable row level security',target_schema,t.relname);
  execute format('revoke all on %I.%I from public,anon,authenticated',target_schema,t.relname);
  execute format('create policy preview_deny on %I.%I for all to anon,authenticated using(false) with check(false)',target_schema,t.relname);
  if t.nspname='public' then
   execute format('grant select on %I.%I to authenticated',target_schema,t.relname);
   execute format('create policy preview_own_read on %I.%I for select to authenticated using((select auth.uid())=user_id)',target_schema,t.relname);
  end if;
 end loop;
 -- Only immutable/reference data. Never copy tables containing player records.
 foreach signature in array array['catalog_codes','base_decks','reward_catalog','gift_code_rewards','event_definitions','milestone_definitions_v170'] loop
  execute format('insert into aamix_hw01_private.%I select * from aamix_private.%I',signature,signature);
 end loop;
 insert into aamix_hw01_private.deck_registry(id) select id from aamix_hw01_private.base_decks;
 for f in select p.oid,p.proname,n.nspname,pg_get_functiondef(p.oid) definition,
   pg_get_function_identity_arguments(p.oid) args,has_function_privilege('authenticated',p.oid,'EXECUTE') allowed
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='aamix_private' or(n.nspname='public' and p.proname like 'aamix_%') loop
  source:=replace(replace(f.definition,'aamix_private.','aamix_hw01_private.'),'public.aamix_','aamix_hw01.aamix_');
  source:=replace(source,'''1.3''','''1.9-halloween-preview1''');
  source:=replace(source,'pg_advisory_xact_lock(170017,1)','pg_advisory_xact_lock(190001,1)');
  if source like '%aamix_private.%' or source like '%public.aamix_%' then raise exception 'Unmapped live dependency';end if;
  execute source;
  target_schema:=case f.nspname when 'public' then 'aamix_hw01' else 'aamix_hw01_private' end;
  signature:=format('%I.%I(%s)',target_schema,f.proname,f.args);
  execute 'revoke all on function '||signature||' from public,anon,authenticated';
  if f.allowed then execute 'grant execute on function '||signature||' to authenticated';end if;
 end loop;
 for c in select n.nspname,t.relname,k.conname,pg_get_constraintdef(k.oid) definition,rn.nspname ref_schema,rt.relname ref_table
  from pg_constraint k join pg_class t on t.oid=k.conrelid join pg_namespace n on n.oid=t.relnamespace
  join pg_class rt on rt.oid=k.confrelid join pg_namespace rn on rn.oid=rt.relnamespace
  where k.contype='f' and(n.nspname='aamix_private' or(n.nspname='public' and t.relname like 'aamix_%')) loop
  target_schema:=case c.nspname when 'public' then 'aamix_hw01' else 'aamix_hw01_private' end;
  source:=replace(replace(c.definition,'aamix_private.','aamix_hw01_private.'),'public.aamix_','aamix_hw01.aamix_');
  source:=regexp_replace(source,'REFERENCES [^ (]+','REFERENCES '||format('%I.%I',case when c.ref_schema='aamix_private' then 'aamix_hw01_private' when c.ref_schema='public' and c.ref_table like 'aamix_%' then 'aamix_hw01' else c.ref_schema end,c.ref_table));
  execute format('alter table %I.%I add constraint %I %s',target_schema,c.relname,c.conname,source);
 end loop;
 for c in select pg_get_triggerdef(g.oid) definition from pg_trigger g join pg_class t on t.oid=g.tgrelid
  join pg_namespace n on n.oid=t.relnamespace where not g.tgisinternal
  and(n.nspname='aamix_private' or(n.nspname='public' and t.relname like 'aamix_%')) loop
  source:=replace(replace(c.definition,'aamix_private.','aamix_hw01_private.'),'public.aamix_','aamix_hw01.aamix_');
  execute source;
 end loop;
 if exists(select 1 from pg_constraint k join pg_class t on t.oid=k.conrelid join pg_namespace n on n.oid=t.relnamespace
  join pg_class r on r.oid=k.confrelid join pg_namespace rn on rn.oid=r.relnamespace
  where k.contype='f' and n.nspname in('aamix_hw01','aamix_hw01_private') and(rn.nspname='aamix_private' or(rn.nspname='public' and r.relname like 'aamix_%'))) then
  raise exception 'Preview foreign key crosses into live game data';
 end if;
end $clone$;
reset check_function_bodies;

-- Changes below affect only the isolated preview schemas.
create function aamix_hw01_private.canonical_card(code text) returns text language sql immutable set search_path='' as $$select case code when 'H01' then '0104' when 'H02' then '0130' when 'H03' then '0127' when 'H04' then '0102' when 'H05' then '0103' else code end$$;
revoke all on function aamix_hw01_private.canonical_card(text) from public,anon,authenticated;
grant execute on function aamix_hw01_private.canonical_card(text) to authenticated;
insert into aamix_hw01_private.catalog_codes(code) values('H01'),('H02'),('H03'),('H04'),('H05');
insert into aamix_hw01_private.reward_catalog(code,name,card_class,special_weight,is_promotional,is_singular)
 select h.code,r.name,r.card_class,r.special_weight,false,r.is_singular from(values('H01','0104'),('H02','0130'),('H03','0127'),('H04','0102'),('H05','0103')) h(code,base) join aamix_hw01_private.reward_catalog r on r.code=h.base;
alter table aamix_hw01.aamix_match_receipts add column event_battle boolean not null default false;
alter table aamix_hw01_private.mp_rooms add column host_rematch boolean not null default false,add column guest_rematch boolean not null default false,add column host_rematch_ready boolean not null default false,add column guest_rematch_ready boolean not null default false,add column rematch_cancelled boolean not null default false,add column rematch_room uuid,add column host_next_deck jsonb,add column guest_next_deck jsonb;
create table aamix_hw01_private.hw_wallet(user_id uuid primary key references auth.users(id) on delete cascade,halloween_packs integer not null default 10 check(halloween_packs>=0),friend_added boolean not null default false,traded boolean not null default false);
create table aamix_hw01_private.hw_mp_rewards(user_id uuid not null references auth.users(id) on delete cascade,match_id uuid not null references aamix_hw01.aamix_match_receipts(match_id),primary key(user_id,match_id));
create table aamix_hw01_private.mp_rematch_requests(user_id uuid not null references auth.users(id) on delete cascade,request_id uuid not null,payload jsonb not null,primary key(user_id,request_id));
do $$declare t text;begin foreach t in array array['hw_wallet','hw_mp_rewards','mp_rematch_requests'] loop execute format('alter table aamix_hw01_private.%I enable row level security',t);execute format('revoke all on aamix_hw01_private.%I from public,anon,authenticated',t);execute format('create policy server_only on aamix_hw01_private.%I for all to anon,authenticated using(false) with check(false)',t);end loop;end$$;
do $$declare c record;begin for c in select conname from pg_constraint where conrelid='aamix_hw01.aamix_pack_openings'::regclass and contype='c' and pg_get_constraintdef(oid) like '%kind%' loop execute format('alter table aamix_hw01.aamix_pack_openings drop constraint %I',c.conname);end loop;end$$;
alter table aamix_hw01.aamix_pack_openings add constraint halloween_pack_kind check(kind in('tc','normal_card','halloween'));
CREATE OR REPLACE FUNCTION aamix_hw01_private.draw_pack()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare codes jsonb := '[]'::jsonb; selected text; ticket double precision; slot integer;

begin

  perform aamix_hw01_private.reward_user();

  select code into strict selected from aamix_hw01_private.reward_catalog

    where not is_promotional and code not like 'H%' and card_class='Recurso' order by random() limit 1;

  codes := codes || jsonb_build_array(selected);

  for slot in 2..5 loop

    if slot=5 and random()<0.30 then

      ticket := random()*100;

      select code into strict selected from (

        select code,sum(special_weight) over(order by code rows unbounded preceding) as cumulative

        from aamix_hw01_private.reward_catalog where not is_promotional and code not like 'H%' and special_weight>0

      ) weighted where cumulative>ticket order by cumulative limit 1;

    else

      select code into strict selected from aamix_hw01_private.reward_catalog

        where not is_promotional and code not like 'H%' and card_class<>'Recurso' and special_weight=0 order by random() limit 1;

    end if;

    codes := codes || jsonb_build_array(selected);

  end loop;

  if codes ?| array['01a','01b','01c','01d','01e','01f'] then

    raise exception 'Promotional cards are forbidden in packs' using errcode='23514';

  end if;

  return codes;

end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.draw_normal_card()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare selected text;
begin
  perform aamix_hw01_private.reward_user();
  select code into strict selected from aamix_hw01_private.reward_catalog
    where not is_promotional and code not like 'H%' and card_class<>'Recurso' and special_weight=0 order by random() limit 1;
  return jsonb_build_array(selected);
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.shop_catalog()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform aamix_hw01_private.reward_user();
  return coalesce((select jsonb_agg(jsonb_build_object('code',code,'price',
    case when code in('0103','0105','0115','0119') then 500 else 150 end) order by code)
    from aamix_hw01_private.reward_catalog where not is_promotional and code not like 'H%' and card_class<>'Recurso'),'[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.purchase_card(p_request_id uuid, p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_hw01_private.lock_rewards(); receipt aamix_hw01.aamix_shop_purchases%rowtype;
  cost integer; already boolean;
begin
  if p_request_id is null then raise exception 'Purchase request UUID required' using errcode='22023'; end if;
  select * into receipt from aamix_hw01.aamix_shop_purchases where user_id=uid and request_id=p_request_id;
  already:=found;
  if already then
    if receipt.code is distinct from p_code then raise exception 'AAMIX_PURCHASE_REQUEST_MISMATCH' using errcode='22023'; end if;
  else
    select case when code in('0103','0105','0115','0119') then 500 else 150 end into cost
      from aamix_hw01_private.reward_catalog where code=p_code and not is_promotional and code not like 'H%' and card_class<>'Recurso';
    if not found then raise exception 'AAMIX_CARD_NOT_FOR_SALE' using errcode='22023'; end if;
    perform aamix_hw01_private.ensure_restos_welcome();
    update aamix_hw01.aamix_rewards_state set restos=restos-cost where user_id=uid and restos>=cost;
    if not found then raise exception 'AAMIX_INSUFFICIENT_RESTOS' using errcode='22023'; end if;
    insert into aamix_hw01.aamix_shop_purchases(user_id,request_id,code,price) values(uid,p_request_id,p_code,cost) returning * into receipt;
    insert into aamix_hw01.aamix_collection(user_id,code,quantity) values(uid,p_code,1)
      on conflict(user_id,code) do update set quantity=aamix_hw01.aamix_collection.quantity+1;
  end if;
  return aamix_hw01.aamix_inventory()||jsonb_build_object('already_purchased',already,'purchase_code',receipt.code,'purchase_price',receipt.price,
    'purchase',jsonb_build_object('purchase_id',receipt.purchase_id,'request_id',receipt.request_id,'code',receipt.code,'price',receipt.price,'purchased_at',receipt.purchased_at));
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.avatar_allowed_v170(p_uid uuid, p_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$

 select exists(select 1 from aamix_hw01_private.reward_catalog c where c.code=p_code and c.card_class='Aliado' and c.code not like 'H%'

 and ((not c.is_promotional and c.code not in('0112','0113','0114','0126')) or (c.code in('0112','0113','0114','0126','01a','01b') and exists(select 1 from aamix_hw01_private.avatar_unlocks_v170 u where u.user_id=p_uid and u.code=p_code))))

$function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.check_collection_v170(p_uid uuid, p_code text, p_quantity integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare d record;

begin

 if p_quantity>=10 then

  for d in select id from aamix_hw01_private.milestone_definitions_v170 where not secret and card_code=p_code loop

   perform aamix_hw01_private.complete_milestone_v170(p_uid,d.id);

  end loop;

 end if;

 if exists(select 1 from aamix_hw01_private.reward_catalog where code=p_code and not is_promotional)

  and not exists(select 1 from aamix_hw01_private.reward_catalog c where not c.is_promotional and c.code not like 'H%' and not exists(

   select 1 from aamix_hw01.aamix_collection o where o.user_id=p_uid and o.code=c.code and o.quantity>0)) then

  perform aamix_hw01_private.complete_milestone_v170(p_uid,'collect_all_standard');

 end if;

end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.custom_cards(p_uid uuid, p_cards jsonb, p_draft boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare e jsonb; code_value text; amount integer; owned integer; c aamix_hw01_private.reward_catalog%rowtype;

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

    select * into c from aamix_hw01_private.reward_catalog where code=code_value;

    if not found then raise exception 'AAMIX_UNKNOWN_CARD' using errcode='22023'; end if;

    family:=aamix_hw01_private.canonical_card(code_value); family_amount:=coalesce((families->>family)::integer,0)+amount; families:=families||jsonb_build_object(family,family_amount);
    if c.card_class<>'Recurso' and family_amount>(case when c.is_singular then 1 else 3 end) then raise exception 'AAMIX_DECK_COPY_LIMIT' using errcode='22023'; end if;

    select quantity into owned from aamix_hw01.aamix_collection where user_id=p_uid and code=code_value;

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

CREATE OR REPLACE FUNCTION aamix_hw01_private.challenges_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); status jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select jsonb_agg(d || jsonb_build_object(
    'unlocked',true or not exists(select 1 from generate_series(1,(d->>'stage')::integer-1) previous(stage)
      where not exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)),
    'completed',exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer),
    'reward_claimed',exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer)
  ) order by (d->>'stage')::integer) into status from jsonb_array_elements(aamix_hw01_private.challenge_definitions()) d;
  return status;
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.begin_challenge_match(p_request_id uuid, p_deck_id text, p_stage integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_hw01_private.lock_rewards(); receipt aamix_hw01.aamix_match_receipts%rowtype;
  definition jsonb; opponent jsonb; d jsonb;
begin
  if p_request_id is null then raise exception 'Match request UUID required' using errcode='22023'; end if;
  select e into definition from jsonb_array_elements(aamix_hw01_private.challenge_definitions()) e where (e->>'stage')::integer=p_stage;
  if not found then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;
  select * into receipt from aamix_hw01.aamix_match_receipts where user_id=uid and request_id=p_request_id;
  if found then
    if receipt.deck_id<>p_deck_id or receipt.challenge_stage is distinct from p_stage then raise exception 'Request UUID already used for a different match' using errcode='22023'; end if;
    d:=coalesce(receipt.player_deck,aamix_hw01_private.mp_deck(uid,p_deck_id));
  else
    if false and exists(select 1 from generate_series(1,p_stage-1) previous(stage) where not exists(
      select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023'; end if;
    d:=aamix_hw01_private.mp_deck(uid,p_deck_id);
    select jsonb_build_object('id',id,'nombre',name,'portada',cover,'recurso_inicial','0100','cartas',cards) into strict opponent
      from aamix_hw01_private.base_decks where id=definition->>'deck_id';
    insert into aamix_hw01.aamix_match_receipts(user_id,request_id,deck_id,challenge_stage,challenge_opponent,player_deck)
      values(uid,p_request_id,p_deck_id,p_stage,opponent,d) returning * into receipt;
  end if;
  return aamix_hw01.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',receipt.result,
    'challenge_stage',receipt.challenge_stage,'challenge_opponent',receipt.challenge_opponent,'match_deck',d);
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.finish_match(p_match_id uuid, p_result text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare uid uuid:=aamix_hw01_private.lock_rewards(); receipt aamix_hw01.aamix_match_receipts%rowtype;

  today date:=(now() at time zone 'America/Santiago')::date; definition jsonb; granted integer;

  prize integer:=0; already_completed boolean:=false; repeat_prize integer:=0; all_completed boolean:=false;

begin

  if p_result is null or p_result not in('victory','defeat') then raise exception 'Completed victory or defeat required' using errcode='22023'; end if;

  select * into receipt from aamix_hw01.aamix_match_receipts where user_id=uid and match_id=p_match_id for update;

  if not found then raise exception 'Unknown match receipt' using errcode='22023'; end if;

  if receipt.challenge_stage is not null then

    select d into strict definition from jsonb_array_elements(aamix_hw01_private.challenge_definitions()) d where (d->>'stage')::integer=receipt.challenge_stage;

    if receipt.challenge_opponent->>'id' is distinct from definition->>'deck_id' then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;

    already_completed:=exists(select 1 from aamix_hw01.aamix_challenge_completions where user_id=uid and stage=receipt.challenge_stage);

  end if;

  if receipt.result is null then

    if false and receipt.challenge_stage is not null and exists(select 1 from generate_series(1,receipt.challenge_stage-1) previous(stage)

      where not exists(select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then

      raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023';

    end if;

    all_completed:=not exists(select 1 from generate_series(1,5) s(stage) where not exists(

      select 1 from aamix_hw01.aamix_challenge_completions c where c.user_id=uid and c.stage=s.stage));

    if receipt.challenge_stage is not null and p_result='victory' and all_completed then repeat_prize:=5;end if;

    update aamix_hw01.aamix_match_receipts set finished_at=now(),result=p_result,challenge_repeat_restos=repeat_prize where match_id=receipt.match_id;

    if repeat_prize>0 then update aamix_hw01.aamix_rewards_state set restos=restos+repeat_prize where user_id=uid;end if;

    insert into aamix_hw01.aamix_daily_missions(user_id,mission_day,completed_match_id) values(uid,today,receipt.match_id) on conflict(user_id,mission_day) do nothing;

    if receipt.challenge_stage is not null and p_result='victory' then

      insert into aamix_hw01.aamix_challenge_completions(user_id,stage,winning_match_id,reward_packs)

        values(uid,receipt.challenge_stage,receipt.match_id,(definition->>'reward_packs')::integer)

        on conflict(user_id,stage) do nothing returning stage into granted;

      if granted is not null then

        prize:=(definition->>'reward_packs')::integer;

        update aamix_hw01.aamix_rewards_state set packs=packs+prize where user_id=uid;

      end if;

    end if;

  elsif receipt.result<>p_result then raise exception 'Match already finished with another result' using errcode='22023'; end if;

  return aamix_hw01.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',p_result,

    'challenge_stage',receipt.challenge_stage,'challenge_reward_packs',prize,'challenge_already_completed',already_completed,

    'challenge_repeat_restos',case when receipt.result is null then repeat_prize else receipt.challenge_repeat_restos end);

end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.mp_response(p_room_id uuid, p_uid uuid, p_since integer DEFAULT '-1'::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r aamix_hw01_private.mp_rooms%rowtype; s integer; data jsonb;
begin
  select * into strict r from aamix_hw01_private.mp_rooms where id=p_room_id;
  s:=case when p_uid=r.host_id then 0 when p_uid=r.guest_id then 1 else -1 end;
  if s=-1 then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501'; end if;
  data:=jsonb_build_object('protocol',3,'ruleset_version',r.ruleset_version,'room_version',r.room_version,'confirmed',jsonb_build_array(r.host_confirmed,r.guest_confirmed),'room_id',r.id,'code',r.code,'status',r.status,'slot',s,'revision',r.revision,
    'actor_slot',r.actor_slot,'winner',r.winner,'expires_at',r.expires_at,'last_error',r.last_error,
    'finish_reason',r.finish_reason,'opponent_online',case when s=0 then r.guest_seen>now()-interval '20 seconds' else r.host_seen>now()-interval '20 seconds' end,
    'players',jsonb_build_array(
      jsonb_build_object('slot',0,'avatar_code',(select avatar_code from aamix_hw01.aamix_rewards_state where user_id=r.host_id),'name',r.host_name,'deck_id',r.host_deck->>'id','deck_name',r.host_deck->>'nombre','cover',r.host_deck->>'portada'),
      case when r.guest_id is null then null else jsonb_build_object('slot',1,'avatar_code',(select avatar_code from aamix_hw01.aamix_rewards_state where user_id=r.guest_id),'name',r.guest_name,'deck_id',r.guest_deck->>'id','deck_name',r.guest_deck->>'nombre','cover',r.guest_deck->>'portada') end));
  if s=0 then
    data:=data||jsonb_build_object('commands',coalesce((
      select jsonb_agg(jsonb_build_object('request_id',c.request_id,'slot',c.slot,'method',c.method,'args',c.args,'revision',c.revision) order by c.created_at)
      from aamix_hw01_private.mp_commands c where c.room_id=r.id and c.status='pending'),'[]'::jsonb));
    if r.revision=0 or p_since=-1 then
      data:=data||jsonb_build_object('host_deck',r.host_deck,'guest_deck',r.guest_deck);
      data:=jsonb_set(data,'{players,0,deck}',r.host_deck);
    if r.guest_id is not null then data:=jsonb_set(data,'{players,1,deck}',r.guest_deck); end if;
    end if;
  end if;
  if p_since<>r.revision then data:=data||jsonb_build_object('state',case s when 0 then r.host_state else r.guest_view end); end if;
  return data||jsonb_build_object('rematch',jsonb_build_object('requested',jsonb_build_array(r.host_rematch,r.guest_rematch),'ready',jsonb_build_array(r.host_rematch_ready,r.guest_rematch_ready),'cancelled',r.rematch_cancelled,'next_room_id',r.rematch_room,'deck_id',case s when 0 then r.host_next_deck->>'id' else r.guest_next_deck->>'id' end));
end $function$;

CREATE OR REPLACE FUNCTION aamix_hw01_private.mp_notify_room()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

begin

  if tg_op='UPDATE' and new.revision=old.revision and new.status=old.status

    and new.guest_id is not distinct from old.guest_id

    and new.host_confirmed=old.host_confirmed and new.guest_confirmed=old.guest_confirmed and new.room_version=old.room_version then return null; end if;

  perform realtime.send(aamix_hw01_private.mp_response(new.id,new.host_id,-1),'room','aamix:user:'||new.host_id::text,true);

  if new.guest_id is not null then

    perform realtime.send(aamix_hw01_private.mp_response(new.id,new.guest_id,-1),'room','aamix:user:'||new.guest_id::text,true);

  end if;

  return null;

end $function$;

create function aamix_hw01_private.halloween_definition() returns jsonb language sql immutable set search_path='' as $event$ select '{"id": "halloween_2026", "title": "EVENTO HALLOWEEN", "card_code": "0128", "start_day": "2026-10-30", "end_day": "2026-11-01", "battle": true, "battle_id": "halloween", "preview": true, "summary": "La festividad del terror se toma AAMIX, encuentra las cinco Cartas Exclusivas del evento y completa las misiones para obtener recompensas. Durante este evento, los ganadores de batallas multijugador recibirán 1 Sobre AAMIX Halloween.", "missions": [{"id": "play_three", "title": "Juega 3 partidas", "target": 3, "metric": "played", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "play_five", "title": "Juega 5 partidas", "target": 5, "metric": "played", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "win_three", "title": "Gana 3 partidas", "target": 3, "metric": "wins", "scope": "event", "reward": {"halloween_packs": 2}}, {"id": "trade_one", "title": "Intercambia 1 carta", "target": 1, "metric": "trades", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "friend_one", "title": "Añade 1 Amigo", "target": 1, "metric": "friends", "scope": "event", "reward": {"halloween_packs": 1}}, {"id": "event_win_five", "title": "Gana 5 veces la Partida de Evento", "target": 5, "metric": "event_wins", "scope": "event", "reward": {"cards": [{"codigo": "H05", "cantidad": 1}]}}]}'::jsonb $event$;
create function aamix_hw01_private.halloween_deck() returns jsonb language sql immutable set search_path='' as $deck$select '{
  "id": "halloween",
  "nombre": "Mazo Halloween",
  "portada": "custom_restos",
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
'::jsonb $deck$;

-- Server-authoritative preview only. No statement below writes any stable AAMIX table.
create function aamix_hw01_private.bootstrap() returns void language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();fresh uuid;
begin
 insert into aamix_hw01_private.hw_wallet(user_id) values(uid) on conflict do nothing returning user_id into fresh;
 if fresh is null then return;end if;
 insert into aamix_hw01.aamix_rewards_state(user_id,restos,packs,normal_packs,avatar_code) values(uid,5000,3,3,'0108') on conflict(user_id) do nothing;
 insert into aamix_hw01.aamix_restos_welcome(user_id,amount) values(uid,100) on conflict do nothing;
 insert into aamix_hw01.aamix_welcome_packs(user_id,packs,challenge_entered_at) values(uid,1,now()) on conflict do nothing;
 insert into aamix_hw01.aamix_starter_gifts(user_id,deck_id) values(uid,'papito') on conflict do nothing;
 insert into aamix_hw01.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select uid,id,name,cover,cards from aamix_hw01_private.base_decks on conflict do nothing;
 insert into aamix_hw01.aamix_collection(user_id,code,quantity)
  select uid,code,case when card_class='Recurso' then 80 when is_singular then 1 else 3 end
  from aamix_hw01_private.reward_catalog where code not like 'H%' on conflict do nothing;
 update aamix_hw01_private.milestones_v170 set acknowledged_at=now() where user_id=uid and claimed_at is not null;
end $$;

create function aamix_hw01_private.halloween_progress() returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();earned integer;played integer;wins integer;event_wins integer;friend_added boolean;traded boolean;
begin
 perform 1 from aamix_hw01_private.hw_wallet where user_id=uid for update;
 with granted as(
  insert into aamix_hw01_private.hw_mp_rewards(user_id,match_id)
  select uid,r.match_id from aamix_hw01.aamix_match_receipts r where r.user_id=uid and r.online_room_id is not null and r.result='victory'
  on conflict do nothing returning match_id
 )select count(*) into earned from granted;
 if earned>0 then update aamix_hw01_private.hw_wallet set halloween_packs=halloween_packs+earned where user_id=uid;end if;
 update aamix_hw01_private.hw_wallet set
  friend_added=hw_wallet.friend_added or exists(select 1 from aamix_hw01_private.friendships f where uid in(f.low_id,f.high_id) and f.status='accepted'),
  traded=hw_wallet.traded or exists(select 1 from aamix_hw01_private.trade_rooms_v160 t where uid in(t.a_id,t.b_id) and t.status='completed')
  where user_id=uid returning hw_wallet.friend_added,hw_wallet.traded into friend_added,traded;
 select count(*)filter(where result in('victory','defeat')),count(*)filter(where result='victory'),count(*)filter(where result='victory' and event_battle)
  into played,wins,event_wins from aamix_hw01.aamix_match_receipts where user_id=uid;
 return jsonb_build_object('played',played,'wins',wins,'event_wins',event_wins,'friends',case when friend_added then 1 else 0 end,'trades',case when traded then 1 else 0 end);
end $$;

create or replace function aamix_hw01_private.events_inventory() returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();e jsonb:=aamix_hw01_private.halloween_definition();m jsonb;progress jsonb;states jsonb:='[]';
begin
 progress:=aamix_hw01_private.halloween_progress();
 for m in select value from jsonb_array_elements(e->'missions') loop
  states:=states||jsonb_build_array(m||jsonb_build_object('progress',least(coalesce((progress->>(m->>'metric'))::integer,0),(m->>'target')::integer),
   'claimed',exists(select 1 from aamix_hw01_private.event_claims c where c.user_id=uid and c.event_id='halloween_2026' and c.mission_id=m->>'id' and c.period_key='once')));
 end loop;
 return jsonb_build_object('server_time',extract(epoch from now()),'server_day',(now() at time zone 'America/Santiago')::date,
  'events_valid_until',extract(epoch from now()+interval '1 hour'),'events',jsonb_build_array(e||jsonb_build_object('missions',states)),
  'halloween_packs',coalesce((select halloween_packs from aamix_hw01_private.hw_wallet where user_id=uid),0),'preview',true);
end $$;

create or replace function aamix_hw01_private.claim_event_mission(p_event_id text,p_mission_id text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.lock_rewards();status jsonb;m jsonb;reward jsonb;already boolean;card jsonb;
begin
 if p_event_id is distinct from 'halloween_2026' then raise exception 'AAMIX_EVENT_INACTIVE' using errcode='22023';end if;
 status:=aamix_hw01_private.events_inventory();
 select value into m from jsonb_array_elements(status->'events'->0->'missions') where value->>'id'=p_mission_id;
 if m is null then raise exception 'AAMIX_INVALID_MISSION' using errcode='22023';end if;
 already:=(m->>'claimed')::boolean;reward:=m->'reward';
 if not already then
  if(m->>'progress')::integer<(m->>'target')::integer then raise exception 'AAMIX_MISSION_INCOMPLETE' using errcode='22023';end if;
  insert into aamix_hw01_private.event_claims(user_id,event_id,mission_id,period_key,reward) values(uid,p_event_id,p_mission_id,'once',reward);
  update aamix_hw01_private.hw_wallet set halloween_packs=halloween_packs+coalesce((reward->>'halloween_packs')::integer,0) where user_id=uid;
  for card in select value from jsonb_array_elements(coalesce(reward->'cards','[]')) loop
   insert into aamix_hw01.aamix_collection(user_id,code,quantity) values(uid,card->>'codigo',(card->>'cantidad')::integer)
   on conflict(user_id,code) do update set quantity=aamix_hw01.aamix_collection.quantity+excluded.quantity;
  end loop;
 end if;
 return aamix_hw01.aamix_inventory()||jsonb_build_object('already_claimed',already,'event_reward',reward);
end $$;

create function aamix_hw01_private.open_halloween_pack(p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.lock_rewards();opening aamix_hw01.aamix_pack_openings%rowtype;ticket integer;picked_code text;first_copy boolean;
begin
 if p_request_id is null then raise exception 'Opening request UUID required' using errcode='22023';end if;
 select o.* into opening from aamix_hw01.aamix_pack_requests r join aamix_hw01.aamix_pack_openings o on o.opening_id=r.opening_id where r.user_id=uid and r.request_id=p_request_id and o.user_id=uid;
 if not found then
  select * into opening from aamix_hw01.aamix_pack_openings where user_id=uid and revealed_at is null;
  if not found then
   update aamix_hw01_private.hw_wallet set halloween_packs=halloween_packs-1 where user_id=uid and halloween_packs>0;
   if not found then raise exception 'AAMIX_NO_PACKS' using errcode='22023';end if;
   ticket:=floor(random()*10000)::integer;
   picked_code:=case when ticket>=9500 then 'H05' else 'H0'||(ticket/2375+1)::text end;
   first_copy:=not exists(select 1 from aamix_hw01.aamix_collection c where c.user_id=uid and c.code=picked_code and quantity>0);
   insert into aamix_hw01.aamix_pack_openings(user_id,request_id,kind,cards,rules_version,new_card_indices)
    values(uid,p_request_id,'halloween',jsonb_build_array(picked_code),'halloween-preview1',case when first_copy then array[0] else '{}'::integer[] end) returning * into opening;
   insert into aamix_hw01.aamix_collection(user_id,code,quantity) values(uid,picked_code,1) on conflict(user_id,code) do update set quantity=aamix_hw01.aamix_collection.quantity+1;
  end if;
 end if;
 insert into aamix_hw01.aamix_pack_requests(user_id,request_id,opening_id) values(uid,p_request_id,opening.opening_id) on conflict do nothing;
 return aamix_hw01.aamix_inventory()||jsonb_build_object('opening',jsonb_build_object('opening_id',opening.opening_id,'kind',opening.kind,'cards',opening.cards,'new_card_indices',to_jsonb(opening.new_card_indices),'opened_at',opening.opened_at,'revealed_at',opening.revealed_at));
end $$;
create function aamix_hw01.aamix_open_halloween_pack(p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select aamix_hw01_private.open_halloween_pack(p_request_id)$$;

create function aamix_hw01_private.begin_event_match(p_request_id uuid,p_deck_id text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.lock_rewards();receipt aamix_hw01.aamix_match_receipts%rowtype;response jsonb;
begin
 if p_request_id is null then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 select * into receipt from aamix_hw01.aamix_match_receipts where user_id=uid and request_id=p_request_id;
 if found then
  if not receipt.event_battle or receipt.deck_id is distinct from p_deck_id then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023';end if;
  response:=aamix_hw01.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_deck',receipt.player_deck);
 else
  response:=aamix_hw01_private.begin_match(p_request_id,p_deck_id);
  update aamix_hw01.aamix_match_receipts set event_battle=true where match_id=(response->>'match_id')::uuid and user_id=uid;
 end if;
 return response||jsonb_build_object('event_battle',true,'event_opponent',aamix_hw01_private.halloween_deck());
end $$;
create function aamix_hw01.aamix_begin_event_match(p_request_id uuid,p_deck_id text) returns jsonb language sql security invoker set search_path='' as $$select aamix_hw01_private.begin_event_match(p_request_id,p_deck_id)$$;

-- Only this copied calendar is forced active. The response retains the planned dates.
update aamix_hw01_private.event_definitions set start_day='2026-01-01',end_day='2099-12-31' where id='halloween_2026';
update aamix_hw01_private.gift_code_rewards set cards='[{"codigo":"01b","cantidad":1}]',avatar_code='01b' where gift_code='GATONEGRO';

-- Fixed-schema, named-parameter RPC gateway. Authentication and RLS remain in force.
create function public.aamix_hw01_call(p_method text,p_args jsonb default '{}') returns jsonb language plpgsql security invoker set search_path='' as $$
#variable_conflict use_column
declare fn record;arg_name text;args text:='';i integer;value_type text;result jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 if p_method is null or p_method!~'^aamix_[a-z0-9_]+$' or p_args is null or jsonb_typeof(p_args)<>'object' or octet_length(p_args::text)>524288 then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 select p.* into fn from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='aamix_hw01' and p.proname=p_method and p.prorettype='jsonb'::regtype and has_function_privilege('authenticated',p.oid,'EXECUTE');
 if not found then raise exception 'AAMIX_PREVIEW_METHOD_UNAVAILABLE' using errcode='22023';end if;
 for arg_name in select jsonb_object_keys(p_args) loop
  if not arg_name=any(coalesce(fn.proargnames,'{}')) then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 end loop;
 perform aamix_hw01_private.bootstrap();
 for i in 1..fn.pronargs loop
  arg_name:=fn.proargnames[i];
  if not p_args?arg_name then continue;end if;
  value_type:=format_type(fn.proargtypes[i-1],null);
  args:=args||case when args='' then '' else ',' end||format('%I => ($1 %s %L)::%s',arg_name,case when value_type='jsonb' then '->' else '->>' end,arg_name,value_type);
 end loop;
 execute format('select aamix_hw01.%I(%s)',p_method,args) into result using p_args;
 return result;
end $$;
revoke all on function public.aamix_hw01_call(text,jsonb) from public,anon,authenticated;
grant execute on function public.aamix_hw01_call(text,jsonb) to authenticated;
revoke all on all functions in schema aamix_hw01,aamix_hw01_private from public,anon;
grant execute on function aamix_hw01_private.bootstrap(),aamix_hw01_private.open_halloween_pack(uuid),aamix_hw01_private.begin_event_match(uuid,text) to authenticated;
grant execute on function aamix_hw01.aamix_open_halloween_pack(uuid),aamix_hw01.aamix_begin_event_match(uuid,text) to authenticated;

-- Finished games negotiate a new, independent room. No receipt or revision is reused.
create function aamix_hw01_private.rematch_deck_current(p_uid uuid,p_deck jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare cards jsonb;is_draft boolean;
begin
 select d.cards,d.draft into cards,is_draft from aamix_hw01.aamix_owned_decks d where user_id=p_uid and deck_id=p_deck->>'id' for share;
 if not found then select d.cards,d.draft into cards,is_draft from aamix_hw01.aamix_custom_decks d where user_id=p_uid and deck_id=p_deck->>'id' for share;end if;
 if cards is null or is_draft or cards is distinct from p_deck->'cartas' then return false;end if;
 perform 1 from aamix_hw01.aamix_collection where user_id=p_uid for share;
 return not exists(select 1 from jsonb_array_elements(cards)e where coalesce((select quantity from aamix_hw01.aamix_collection where user_id=p_uid and code=e->>'codigo'),0)<(e->>'cantidad')::integer);
end$$;
revoke all on function aamix_hw01_private.rematch_deck_current(uuid,jsonb) from public,anon,authenticated;
create function aamix_hw01_private.rematch_action(p_room_id uuid,p_request_id uuid,p_action text,p_deck_id text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare uid uuid:=aamix_hw01_private.reward_user();r aamix_hw01_private.mp_rooms%rowtype;
 next_room aamix_hw01_private.mp_rooms%rowtype;payload jsonb;previous jsonb;d jsonb;c text;s integer;
begin
 if p_request_id is null or p_action is null or p_action not in('request','choose','ready','cancel') then raise exception 'AAMIX_INVALID_REQUEST' using errcode='22023';end if;
 -- Same lock ordering as room creation. This lock is exclusive to the preview.
 perform pg_advisory_xact_lock(190001,1);
 select * into r from aamix_hw01_private.mp_rooms where id=p_room_id for update;
 if not found or uid not in(r.host_id,coalesce(r.guest_id,r.host_id)) then raise exception 'AAMIX_ROOM_FORBIDDEN' using errcode='42501';end if;
 s:=case when uid=r.host_id then 0 else 1 end;
 payload:=jsonb_build_object('room',p_room_id,'action',p_action,'deck',p_deck_id);
 select q.payload into previous from aamix_hw01_private.mp_rematch_requests q where q.user_id=uid and q.request_id=p_request_id;
 if found then
  if previous<>payload then raise exception 'AAMIX_REQUEST_REUSED' using errcode='22023';end if;
  return aamix_hw01_private.mp_response(r.id,uid);
 end if;
 if r.status<>'finished' or r.guest_id is null then raise exception 'AAMIX_ROOM_NOT_FINISHED' using errcode='22023';end if;
 if p_action='cancel' then
  if r.rematch_room is not null then
   select * into next_room from aamix_hw01_private.mp_rooms where id=r.rematch_room for update;
   if next_room.status in('waiting','ready','playing') then perform aamix_hw01_private.mp_leave(next_room.id);end if;
  end if;
  update aamix_hw01_private.mp_rooms set rematch_cancelled=true,host_rematch_ready=false,guest_rematch_ready=false,room_version=room_version+1 where id=r.id;
 else
  if r.rematch_cancelled then raise exception 'AAMIX_REMATCH_CANCELLED' using errcode='22023';end if;
  if r.rematch_room is not null then raise exception 'AAMIX_REMATCH_STARTED' using errcode='22023';end if;
  if exists(select 1 from aamix_hw01_private.mp_members where user_id=uid) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023';end if;
  if p_action in('request','choose') then
   d:=aamix_hw01_private.mp_deck(uid,p_deck_id);
   if s=0 then
    update aamix_hw01_private.mp_rooms set host_rematch=true,host_next_deck=d,host_rematch_ready=false,room_version=room_version+1 where id=r.id;
   else
    update aamix_hw01_private.mp_rooms set guest_rematch=true,guest_next_deck=d,guest_rematch_ready=false,room_version=room_version+1 where id=r.id;
   end if;
  else
   if not(r.host_rematch and r.guest_rematch) then raise exception 'AAMIX_REMATCH_WAITING' using errcode='22023';end if;
   -- Validate ownership and playability again when confirming.
   d:=aamix_hw01_private.mp_deck(uid,case s when 0 then r.host_next_deck->>'id' else r.guest_next_deck->>'id' end);
   if s=0 then update aamix_hw01_private.mp_rooms set host_next_deck=d,host_rematch_ready=true,room_version=room_version+1 where id=r.id;
   else update aamix_hw01_private.mp_rooms set guest_next_deck=d,guest_rematch_ready=true,room_version=room_version+1 where id=r.id;end if;
  end if;
  select * into r from aamix_hw01_private.mp_rooms where id=p_room_id;
  if r.host_rematch and r.guest_rematch and r.host_rematch_ready and r.guest_rematch_ready then
   if exists(select 1 from aamix_hw01_private.mp_members where user_id in(r.host_id,r.guest_id)) then raise exception 'AAMIX_ALREADY_IN_ROOM' using errcode='22023';end if;
   if not aamix_hw01_private.rematch_deck_current(r.host_id,r.host_next_deck) or not aamix_hw01_private.rematch_deck_current(r.guest_id,r.guest_next_deck) then raise exception 'AAMIX_DECK_CHANGED' using errcode='22023';end if;
   loop
    c:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from aamix_hw01_private.mp_rooms where code=c);
   end loop;
   insert into aamix_hw01_private.mp_rooms(code,host_id,guest_id,create_request,join_request,host_deck,guest_deck,host_name,guest_name,status,host_confirmed,guest_confirmed,guest_seen,ruleset_version)
    values(c,r.host_id,r.guest_id,gen_random_uuid(),gen_random_uuid(),r.host_next_deck,r.guest_next_deck,r.host_name,r.guest_name,'ready',true,true,now(),r.ruleset_version) returning * into next_room;
   insert into aamix_hw01_private.mp_members(user_id,room_id) values(r.host_id,next_room.id),(r.guest_id,next_room.id);
   update aamix_hw01_private.mp_rooms set rematch_room=next_room.id,room_version=room_version+1 where id=r.id;
  end if;
 end if;
 insert into aamix_hw01_private.mp_rematch_requests(user_id,request_id,payload) values(uid,p_request_id,payload);
 return aamix_hw01_private.mp_response(r.id,uid);
end $$;
create function aamix_hw01.aamix_mp_rematch(p_room_id uuid,p_request_id uuid,p_action text,p_deck_id text default null)
returns jsonb language sql security invoker set search_path='' as $$select aamix_hw01_private.rematch_action(p_room_id,p_request_id,p_action,p_deck_id)$$;
revoke all on function aamix_hw01_private.rematch_action(uuid,uuid,text,text),aamix_hw01.aamix_mp_rematch(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function aamix_hw01_private.rematch_action(uuid,uuid,text,text),aamix_hw01.aamix_mp_rematch(uuid,uuid,text,text) to authenticated;

-- Reuse of an event receipt through the ordinary start endpoint is rejected too.
do $$declare definition text;begin
 select pg_get_functiondef('aamix_hw01_private.begin_match(uuid,text)'::regprocedure) into definition;
 definition:=replace(definition,'or receipt.online_room_id is not null then','or receipt.online_room_id is not null or receipt.event_battle then');
 execute definition;
end$$;
