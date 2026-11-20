-- AAMIX Online v1.0, semantic updater1.8.0. Additive: no resets, no replay of old migrations.
alter table public.aamix_match_receipts add column challenge_repeat_restos integer not null default 0 check(challenge_repeat_restos in(0,5));
update aamix_private.event_definitions set start_day='2026-10-23',end_day='2026-10-26' where id='bienvenida_2026';

create table aamix_private.deleted_custom_decks_v180(
 user_id uuid not null references auth.users(id) on delete cascade,
 deck_id text not null,revision integer not null,deleted_at timestamptz not null default now(),
 primary key(user_id,deck_id)
);
alter table aamix_private.deleted_custom_decks_v180 enable row level security;
revoke all on aamix_private.deleted_custom_decks_v180 from public,anon,authenticated;
create policy deleted_decks_server_only on aamix_private.deleted_custom_decks_v180 for all to anon,authenticated using(false) with check(false);

create function aamix_private.delete_custom_deck_v180(p_deck_id text,p_expected_revision integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); d public.aamix_custom_decks%rowtype;
begin
 if p_deck_id is null or p_deck_id !~ '^custom_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
  raise exception 'AAMIX_DECK_IMMUTABLE' using errcode='22023';end if;
 if p_expected_revision is null or p_expected_revision<1 then raise exception 'AAMIX_INVALID_DECK' using errcode='22023';end if;
 if exists(select 1 from aamix_private.deleted_custom_decks_v180 where user_id=uid and deck_id=p_deck_id) then
  return public.aamix_inventory()||jsonb_build_object('deleted_deck_id',p_deck_id,'already_deleted',true);end if;
 select * into d from public.aamix_custom_decks where user_id=uid and deck_id=p_deck_id for update;
 if not found then raise exception 'AAMIX_UNOWNED_DECK' using errcode='22023';end if;
 if d.revision<>p_expected_revision then raise exception 'AAMIX_DECK_REVISION_CONFLICT' using errcode='40001';end if;
 if exists(select 1 from aamix_private.mp_rooms r where r.status in('waiting','ready','playing') and r.expires_at>now()
   and ((r.host_id=uid and r.host_deck->>'id'=p_deck_id) or(r.guest_id=uid and r.guest_deck->>'id'=p_deck_id))) then
  raise exception 'AAMIX_DECK_IN_ROOM' using errcode='22023';end if;
 insert into aamix_private.deleted_custom_decks_v180(user_id,deck_id,revision) values(uid,p_deck_id,d.revision);
 delete from public.aamix_custom_decks where user_id=uid and deck_id=p_deck_id;
 -- Registry and match/save receipts are deliberately retained. Inventory/cards never change.
 return public.aamix_inventory()||jsonb_build_object('deleted_deck_id',p_deck_id,'already_deleted',false);
end $$;
revoke all on function aamix_private.delete_custom_deck_v180(text,integer) from public,anon,authenticated;
grant execute on function aamix_private.delete_custom_deck_v180(text,integer) to authenticated;
create function public.aamix_delete_custom_deck(p_deck_id text,p_expected_revision integer) returns jsonb
language sql security invoker set search_path='' as $$select aamix_private.delete_custom_deck_v180(p_deck_id,p_expected_revision)$$;
revoke all on function public.aamix_delete_custom_deck(text,integer) from public,anon,authenticated;
grant execute on function public.aamix_delete_custom_deck(text,integer) to authenticated;

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
    all_completed:=not exists(select 1 from generate_series(1,5) s(stage) where not exists(
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
