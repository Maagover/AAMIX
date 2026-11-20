-- Official AAMIX challenge extension, stages 6..11. No player reset or test data.
-- The separate authorized legacy-reward correction calls a postgres-only helper; no IDs are embedded here.
alter table public.aamix_challenge_completions drop constraint aamix_challenge_completions_stage_check,drop constraint aamix_challenge_completions_check;
alter table public.aamix_challenge_completions add constraint aamix_challenge_completions_stage_check check(stage between 1 and 11),add constraint aamix_challenge_completions_check check(reward_packs=case when stage in(1,2,3) then 1 when stage=4 then 2 else 3 end);
alter table public.aamix_match_receipts drop constraint aamix_match_receipts_challenge_stage_check,drop constraint aamix_challenge_receipt_shape;
alter table public.aamix_match_receipts add constraint aamix_match_receipts_challenge_stage_check check(challenge_stage between 1 and 11);


alter table public.aamix_match_receipts add constraint aamix_challenge_receipt_shape check((challenge_stage is null and challenge_opponent is null)or coalesce(challenge_stage is not null and challenge_opponent is not null and jsonb_typeof(challenge_opponent)='object' and challenge_opponent->>'id'=case challenge_stage when 1 then 'papito' when 2 then 'flaan' when 3 then 'kajido' when 4 then 'maago' when 5 then 'girabl' when 6 then 'dominios' when 7 then 'miku' when 8 then 'tsuki_akira' when 9 then 'imbloqueable' when 10 then 'chanchuus' when 11 then 'transmision' end and jsonb_typeof(challenge_opponent->'cartas')='array',false));

alter table public.aamix_custom_decks drop constraint custom_cover_v170;alter table public.aamix_custom_decks add constraint custom_cover_v170 check(cover in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin','custom_kajido','custom_maagover','custom_girabl','custom_dominios','custom_miku','custom_tsuki_desafio','custom_imbloqueable','custom_chanchuus_aliado','custom_transmision_desafio'));

alter table aamix_private.mission_design_unlocks_v170 drop constraint mission_design_unlocks_v170_design_check;alter table aamix_private.mission_design_unlocks_v170 add constraint mission_design_unlocks_v170_design_check check(design in('custom_maagover','custom_girabl','custom_dominios','custom_miku','custom_tsuki_desafio','custom_imbloqueable','custom_chanchuus_aliado','custom_transmision_desafio'));

insert into aamix_private.deck_registry(id) values('dominios');insert into aamix_private.base_decks(id,name,cover,cards)values('dominios','Mazo Dominios','dominios','[{"codigo": "0100", "cantidad": 15}, {"codigo": "0109", "cantidad": 3}, {"codigo": "0114", "cantidad": 3}, {"codigo": "0101", "cantidad": 1}, {"codigo": "0104", "cantidad": 2}, {"codigo": "0111", "cantidad": 2}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 3}, {"codigo": "0132", "cantidad": 3}, {"codigo": "0122", "cantidad": 2}, {"codigo": "0121", "cantidad": 2}, {"codigo": "0131", "cantidad": 2}]'::jsonb);

insert into aamix_private.milestone_definitions_v170(id,title,secret,target,card_code,reward_kind,reward_code)values('challenge_design_6','Derrota a Mazo Dominios en Desafío AAMIX',true,1,null,'design','custom_dominios');

insert into aamix_private.deck_registry(id) values('miku');insert into aamix_private.base_decks(id,name,cover,cards)values('miku','Mazo Miku','miku','[{"codigo": "0100", "cantidad": 14}, {"codigo": "0107", "cantidad": 3}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0108", "cantidad": 3}, {"codigo": "0114", "cantidad": 2}, {"codigo": "0101", "cantidad": 1}, {"codigo": "0111", "cantidad": 2}, {"codigo": "0110", "cantidad": 1}, {"codigo": "01b", "cantidad": 1}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 3}, {"codigo": "0133", "cantidad": 1}, {"codigo": "0119", "cantidad": 1}, {"codigo": "0124", "cantidad": 3}]'::jsonb);

insert into aamix_private.milestone_definitions_v170(id,title,secret,target,card_code,reward_kind,reward_code)values('challenge_design_7','Derrota a Mazo Miku en Desafío AAMIX',true,1,null,'design','custom_miku');

insert into aamix_private.deck_registry(id) values('tsuki_akira');insert into aamix_private.base_decks(id,name,cover,cards)values('tsuki_akira','Mazo Tsuki y Akira','tsuki_akira','[{"codigo": "0100", "cantidad": 17}, {"codigo": "01c", "cantidad": 1}, {"codigo": "0103", "cantidad": 1}, {"codigo": "0112", "cantidad": 3}, {"codigo": "0113", "cantidad": 3}, {"codigo": "01a", "cantidad": 3}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0127", "cantidad": 3}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 3}, {"codigo": "0117", "cantidad": 1}]'::jsonb);

insert into aamix_private.milestone_definitions_v170(id,title,secret,target,card_code,reward_kind,reward_code)values('challenge_design_8','Derrota a Mazo Tsuki y Akira en Desafío AAMIX',true,1,null,'design','custom_tsuki_desafio');

insert into aamix_private.deck_registry(id) values('imbloqueable');insert into aamix_private.base_decks(id,name,cover,cards)values('imbloqueable','Mazo Imbloqueable','imbloqueable','[{"codigo": "0100", "cantidad": 17}, {"codigo": "0102", "cantidad": 2}, {"codigo": "0107", "cantidad": 3}, {"codigo": "0108", "cantidad": 2}, {"codigo": "0128", "cantidad": 2}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0129", "cantidad": 3}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 3}, {"codigo": "0124", "cantidad": 3}]'::jsonb);

insert into aamix_private.milestone_definitions_v170(id,title,secret,target,card_code,reward_kind,reward_code)values('challenge_design_9','Derrota a Mazo Imbloqueable en Desafío AAMIX',true,1,null,'design','custom_imbloqueable');

insert into aamix_private.deck_registry(id) values('chanchuus');insert into aamix_private.base_decks(id,name,cover,cards)values('chanchuus','Mazo Chanchuus','chanchuus','[{"codigo": "0100", "cantidad": 15}, {"codigo": "0125", "cantidad": 3}, {"codigo": "0108", "cantidad": 3}, {"codigo": "0111", "cantidad": 3}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0128", "cantidad": 3}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 2}, {"codigo": "0118", "cantidad": 2}, {"codigo": "01d", "cantidad": 2}, {"codigo": "0124", "cantidad": 1}, {"codigo": "0119", "cantidad": 1}]'::jsonb);

insert into aamix_private.milestone_definitions_v170(id,title,secret,target,card_code,reward_kind,reward_code)values('challenge_design_10','Derrota a Mazo Chanchuus en Desafío AAMIX',true,1,null,'design','custom_chanchuus_aliado');

insert into aamix_private.deck_registry(id) values('transmision');insert into aamix_private.base_decks(id,name,cover,cards)values('transmision','Transmisión Caída','transmision','[{"codigo": "0100", "cantidad": 15}, {"codigo": "01c", "cantidad": 1}, {"codigo": "0104", "cantidad": 3}, {"codigo": "0108", "cantidad": 3}, {"codigo": "0111", "cantidad": 3}, {"codigo": "0107", "cantidad": 2}, {"codigo": "0129", "cantidad": 2}, {"codigo": "0126", "cantidad": 1}, {"codigo": "0110", "cantidad": 1}, {"codigo": "0105", "cantidad": 1}, {"codigo": "0116", "cantidad": 2}, {"codigo": "0120", "cantidad": 2}, {"codigo": "01d", "cantidad": 1}, {"codigo": "0124", "cantidad": 2}, {"codigo": "0119", "cantidad": 1}]'::jsonb);

insert into aamix_private.milestone_definitions_v170(id,title,secret,target,card_code,reward_kind,reward_code)values('challenge_design_11','Derrota a Transmisión Caída en Desafío AAMIX',true,1,null,'design','custom_transmision_desafio');

create or replace function aamix_private.challenge_definitions() returns jsonb language sql immutable set search_path='' as $d$select '[{"stage": 1, "deck_id": "papito", "title": "Mazo Papito", "reward_packs": 1}, {"stage": 2, "deck_id": "flaan", "title": "Mazo Flaan", "reward_packs": 1}, {"stage": 3, "deck_id": "kajido", "title": "Mazo Kajido", "reward_packs": 1}, {"stage": 4, "deck_id": "maago", "title": "Mazo Maagover", "reward_packs": 2}, {"stage": 5, "deck_id": "girabl", "title": "Mazo Girabl", "reward_packs": 3}, {"stage": 6, "deck_id": "dominios", "title": "Mazo Dominios", "reward_packs": 3, "reward_cover": "custom_dominios"}, {"stage": 7, "deck_id": "miku", "title": "Mazo Miku", "reward_packs": 3, "reward_cover": "custom_miku"}, {"stage": 8, "deck_id": "tsuki_akira", "title": "Mazo Tsuki y Akira", "reward_packs": 3, "reward_cover": "custom_tsuki_desafio"}, {"stage": 9, "deck_id": "imbloqueable", "title": "Mazo Imbloqueable", "reward_packs": 3, "reward_cover": "custom_imbloqueable"}, {"stage": 10, "deck_id": "chanchuus", "title": "Mazo Chanchuus", "reward_packs": 3, "reward_cover": "custom_chanchuus_aliado"}, {"stage": 11, "deck_id": "transmision", "title": "Transmisión Caída", "reward_packs": 3, "reward_cover": "custom_transmision_desafio"}]'::jsonb$d$;

create or replace function aamix_private.check_challenge_v170(p_uid uuid) returns void language plpgsql security definer set search_path='' as $$
declare d jsonb;
begin
 if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=4)then perform aamix_private.complete_milestone_v170(p_uid,'challenge_maagover');end if;
 if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=5)then perform aamix_private.complete_milestone_v170(p_uid,'challenge_girabl');end if;
 for d in select value from jsonb_array_elements(aamix_private.challenge_definitions()) where (value->>'stage')::integer>=6 loop
  if exists(select 1 from public.aamix_challenge_completions where user_id=p_uid and stage=(d->>'stage')::integer)then perform aamix_private.complete_milestone_v170(p_uid,'challenge_design_'||(d->>'stage'));end if;
 end loop;
 if not exists(select 1 from jsonb_array_elements(aamix_private.challenge_definitions()) as definitions(entry) where not exists(select 1 from public.aamix_challenge_completions c where c.user_id=p_uid and c.stage=(definitions.entry->>'stage')::integer))then
  perform aamix_private.complete_milestone_v170(p_uid,'challenge_complete');
 end if;
end$$;


CREATE OR REPLACE FUNCTION aamix_private.finish_match(p_match_id uuid, p_result text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype;
  today date:=(now() at time zone 'America/Santiago')::date; definition jsonb; granted integer;
  prize integer:=0; already_completed boolean:=false; repeat_prize integer:=0; all_completed boolean:=false;
begin
  if p_result is null or p_result not in('victory','defeat') then raise exception 'Completed victory or defeat required' using errcode='22023'; end if;
  select * into receipt from public.aamix_match_receipts where user_id=uid and match_id=p_match_id for update;
  if not found then raise exception 'Unknown match receipt' using errcode='22023'; end if;
  if receipt.challenge_stage is not null then
    select d into strict definition from jsonb_array_elements(aamix_private.challenge_definitions()) d where (d->>'stage')::integer=receipt.challenge_stage;
    if receipt.challenge_opponent->>'id' is distinct from definition->>'deck_id' then raise exception 'AAMIX_INVALID_CHALLENGE' using errcode='22023'; end if;
    already_completed:=exists(select 1 from public.aamix_challenge_completions where user_id=uid and stage=receipt.challenge_stage);
  end if;
  if receipt.result is null then
    if receipt.challenge_stage is not null and exists(select 1 from generate_series(1,receipt.challenge_stage-1) previous(stage)
      where not exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=previous.stage)) then
      raise exception 'AAMIX_CHALLENGE_LOCKED' using errcode='22023';
    end if;
    all_completed:=not exists(select 1 from generate_series(1,jsonb_array_length(aamix_private.challenge_definitions())) s(stage) where not exists(
      select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=s.stage));
    if receipt.challenge_stage is not null and p_result='victory' and all_completed then repeat_prize:=5;end if;
    update public.aamix_match_receipts set finished_at=now(),result=p_result,challenge_repeat_restos=repeat_prize where match_id=receipt.match_id;
    if repeat_prize>0 then update public.aamix_rewards_state set restos=restos+repeat_prize where user_id=uid;end if;
    insert into public.aamix_daily_missions(user_id,mission_day,completed_match_id) values(uid,today,receipt.match_id) on conflict(user_id,mission_day) do nothing;
    if receipt.challenge_stage is not null and p_result='victory' then
      insert into public.aamix_challenge_completions(user_id,stage,winning_match_id,reward_packs)
        values(uid,receipt.challenge_stage,receipt.match_id,(definition->>'reward_packs')::integer)
        on conflict(user_id,stage) do nothing returning stage into granted;
      if granted is not null then
        prize:=(definition->>'reward_packs')::integer;
        update public.aamix_rewards_state set packs=packs+prize where user_id=uid;
      end if;
    end if;
  elsif receipt.result<>p_result then raise exception 'Match already finished with another result' using errcode='22023'; end if;
  return public.aamix_inventory()||jsonb_build_object('match_id',receipt.match_id,'match_result',p_result,
    'challenge_stage',receipt.challenge_stage,'challenge_reward_packs',prize,'challenge_already_completed',already_completed,
    'challenge_repeat_restos',case when receipt.result is null then repeat_prize else receipt.challenge_repeat_restos end);
end $function$;

CREATE OR REPLACE FUNCTION aamix_private.deck_designs_inventory()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=auth.uid(); unlocked jsonb;
begin
  if uid is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select coalesce(jsonb_agg(design.id order by design.position),'[]'::jsonb) into unlocked
  from (values('custom_tsuki_akira',1),('custom_chanchuus',2),('custom_viborin',3),('custom_kajido',4),('custom_maagover',5),('custom_girabl',6),('custom_dominios',7),('custom_miku',8),('custom_tsuki_desafio',9),('custom_imbloqueable',10),('custom_chanchuus_aliado',11),('custom_transmision_desafio',12)) design(id,position)
  where exists(
    select 1 from public.aamix_code_redemptions redeemed
    where redeemed.user_id=uid and redeemed.deck_design=design.id
  ) or exists(select 1 from aamix_private.event_design_unlocks earned where earned.user_id=uid and earned.design=design.id) or exists(select 1 from aamix_private.mission_design_unlocks_v170 m where m.user_id=uid and m.design=design.id);
  return jsonb_build_object(
    'available_custom_covers','["custom_transmision","custom_restos"]'::jsonb||unlocked,
    'unlocked_deck_designs',unlocked);
end $function$;

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
  if normalized_id<>'' and normalized_id not like 'custom_%' then return aamix_private.save_repaired_deck(p_request_id,p_deck_id,p_nombre,p_portada,p_cartas,p_draft,p_expected_revision);end if;
  if p_request_id is null or p_expected_revision is null or p_expected_revision<0 or p_draft is null
    or normalized_name is null or char_length(normalized_name) not between 1 and 48 or normalized_name ~ '[[:cntrl:]]'
    or p_portada is null or p_portada not in('custom_transmision','custom_restos','custom_tsuki_akira','custom_chanchuus','custom_viborin','custom_kajido','custom_maagover','custom_girabl','custom_dominios','custom_miku','custom_tsuki_desafio','custom_imbloqueable','custom_chanchuus_aliado','custom_transmision_desafio')
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
  ) and not exists(select 1 from aamix_private.event_design_unlocks earned where earned.user_id=uid and earned.design=p_portada) and not exists(select 1 from aamix_private.mission_design_unlocks_v170 earned where earned.user_id=uid and earned.design=p_portada) then raise exception 'AAMIX_DECK_COVER_LOCKED' using errcode='22023'; end if;
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

create table aamix_private.challenge_extension_revocations_v110(
 user_id uuid primary key references auth.users(id)on delete cascade,
 previous_milestone jsonb not null,previous_quantity integer not null,removed_quantity integer not null check(removed_quantity in(0,1)),
 repaired_decks jsonb not null default '[]',applied_at timestamptz not null default now());
alter table aamix_private.challenge_extension_revocations_v110 enable row level security;
create policy server_only on aamix_private.challenge_extension_revocations_v110 for all to anon,authenticated using(false)with check(false);
revoke all on aamix_private.challenge_extension_revocations_v110 from public,anon,authenticated;
create function aamix_private.revoke_legacy_challenge_v110(p_uid uuid)returns jsonb language plpgsql security invoker set search_path='' as $$
declare previous aamix_private.milestones_v170%rowtype;amount integer:=0;removed integer:=0;repaired jsonb:='[]';
begin
 perform 1 from public.aamix_rewards_state where user_id=p_uid for update;
 if not found then raise exception 'Unknown player';end if;
 if exists(select 1 from aamix_private.challenge_extension_revocations_v110 where user_id=p_uid)then return jsonb_build_object('already_applied',true);end if;
 select * into previous from aamix_private.milestones_v170 where user_id=p_uid and mission_id='challenge_complete' for update;
 if not found then return jsonb_build_object('not_applicable',true);end if;
 if not exists(select 1 from jsonb_array_elements(aamix_private.challenge_definitions())d where not exists(select 1 from public.aamix_challenge_completions c where c.user_id=p_uid and c.stage=(d->>'stage')::integer))then raise exception 'Already completed extended challenge';end if;
 select quantity into amount from public.aamix_collection where user_id=p_uid and code='01d'for update;amount:=coalesce(amount,0);
 if previous.claimed_at is not null and amount>0 then removed:=1;end if;
 insert into aamix_private.challenge_extension_revocations_v110(user_id,previous_milestone,previous_quantity,removed_quantity)values(p_uid,to_jsonb(previous),amount,removed);
 if removed=1 then
  if amount=1 then delete from public.aamix_collection where user_id=p_uid and code='01d';else update public.aamix_collection set quantity=quantity-1 where user_id=p_uid and code='01d';end if;
  repaired:=aamix_private.trade_trim_decks(p_uid);
 end if;
 delete from aamix_private.milestones_v170 where user_id=p_uid and mission_id='challenge_complete';
 update aamix_private.challenge_extension_revocations_v110 set repaired_decks=repaired where user_id=p_uid;
 return jsonb_build_object('removed_quantity',removed,'repaired_decks',repaired,'levels_preserved',true);
end$$;
revoke all on function aamix_private.revoke_legacy_challenge_v110(uuid)from public,anon,authenticated;
NOTIFY pgrst,'reload schema';
