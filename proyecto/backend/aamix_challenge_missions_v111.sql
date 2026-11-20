-- Additive only. No account resets, no old reward or receipt modifications.
create table aamix_private.challenge_metrics_v111(
 user_id uuid not null references auth.users(id) on delete cascade,
 match_id uuid primary key references public.aamix_match_receipts(match_id) on delete cascade,
 deck_remaining integer not null check(deck_remaining between 0 and 40),
 allies_lost integer not null check(allies_lost between 0 and 10000));
create table aamix_private.challenge_claims_v111(
 user_id uuid not null references auth.users(id) on delete cascade,
 stage integer not null check(stage between 1 and 11),mission_id text not null,
 claimed_at timestamptz not null default now(),primary key(user_id,stage,mission_id));
alter table aamix_private.challenge_metrics_v111 enable row level security;
alter table aamix_private.challenge_claims_v111 enable row level security;
revoke all on aamix_private.challenge_metrics_v111,aamix_private.challenge_claims_v111 from public,anon,authenticated;

create function aamix_private.challenge_missions_v111(p_stage integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); result jsonb:='[]'; m jsonb; progress integer; claimed boolean;
begin
 if uid is null then raise exception 'Authentication required' using errcode='28000';end if;
 if p_stage not between 1 and 11 then raise exception 'Invalid stage';end if;
 for m in select value from jsonb_array_elements(
  '[{"id":"win_five","title":"Gana 5 partidas","goal":5,"reward_packs":2}]'::jsonb
  ||case when p_stage>=4 then '[{"id":"no_singular","title":"Gana 1 partida sin Cartas Singulares en tu mazo","goal":1,"reward_packs":1}]'::jsonb else '[]'::jsonb end
  ||case when p_stage>=6 then '[{"id":"keep_twenty","title":"Gana 1 partida con más de 20 cartas en tu Mazo","goal":1,"reward_packs":1}]'::jsonb else '[]'::jsonb end
  ||case when p_stage=11 then '[{"id":"no_losses","title":"Gana 1 partida sin perder ningún Aliado","goal":1,"reward_packs":3}]'::jsonb else '[]'::jsonb end) loop
  select count(*) into progress from public.aamix_match_receipts r
  left join aamix_private.challenge_metrics_v111 t on t.match_id=r.match_id and t.user_id=uid
  where r.user_id=uid and r.challenge_stage=p_stage and r.result='victory' and
   case m->>'id'
    when 'win_five' then true
    when 'no_singular' then r.player_deck is not null and not exists(
     select 1 from jsonb_array_elements(r.player_deck->'cartas') card where card->>'codigo' in('0103','0105','0115','0119','01c','01e','01f','H05') and (card->>'cantidad')::integer>0)
    when 'keep_twenty' then t.deck_remaining>20
    when 'no_losses' then t.allies_lost=0
    else false end;
  claimed:=exists(select 1 from aamix_private.challenge_claims_v111 x where x.user_id=uid and x.stage=p_stage and x.mission_id=m->>'id');
  result:=result||jsonb_build_array(m||jsonb_build_object('progress',least(progress,(m->>'goal')::integer),'claimed',claimed,'can_claim',not claimed and progress>=(m->>'goal')::integer));
 end loop;
 return result;
end$$;
revoke all on function aamix_private.challenge_missions_v111(integer) from public,anon,authenticated;
grant execute on function aamix_private.challenge_missions_v111(integer) to authenticated;

create or replace function aamix_private.challenges_status() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); status jsonb;
begin
 if uid is null then raise exception 'Authentication required' using errcode='28000';end if;
 select jsonb_agg(d||jsonb_build_object(
 'unlocked',not exists(select 1 from generate_series(1,(d->>'stage')::integer-1) s(stage) where not exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=s.stage)),
 'completed',exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer),
 'reward_claimed',exists(select 1 from public.aamix_challenge_completions c where c.user_id=uid and c.stage=(d->>'stage')::integer),
 'missions',aamix_private.challenge_missions_v111((d->>'stage')::integer)) order by (d->>'stage')::integer)
 into status from jsonb_array_elements(aamix_private.challenge_definitions()) d;
 return status;
end$$;

create function aamix_private.finish_challenge_v111(p_match_id uuid,p_result text,p_metrics jsonb)returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); receipt public.aamix_match_receipts%rowtype; reply jsonb;
begin
 select * into receipt from public.aamix_match_receipts where user_id=uid and match_id=p_match_id for update;
 if not found then raise exception 'Unknown match receipt' using errcode='22023';end if;
 if receipt.result is null and receipt.challenge_stage is not null then
  if jsonb_typeof(p_metrics)<>'object' or not(p_metrics ? 'deck_remaining' and p_metrics ? 'allies_lost') then raise exception 'Metrics required' using errcode='22023';end if;
  insert into aamix_private.challenge_metrics_v111 values(uid,p_match_id,(p_metrics->>'deck_remaining')::integer,(p_metrics->>'allies_lost')::integer);
 end if;
 reply:=aamix_private.finish_match(p_match_id,p_result);
 return reply||jsonb_build_object('challenges',aamix_private.challenges_status());
end$$;
revoke all on function aamix_private.finish_challenge_v111(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function aamix_private.finish_challenge_v111(uuid,text,jsonb) to authenticated;
create function public.aamix_finish_challenge_v111(p_match_id uuid,p_result text,p_metrics jsonb)returns jsonb
language sql security invoker set search_path='' as $$select aamix_private.finish_challenge_v111(p_match_id,p_result,p_metrics);$$;
revoke all on function public.aamix_finish_challenge_v111(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.aamix_finish_challenge_v111(uuid,text,jsonb) to authenticated;

create function aamix_private.claim_challenge_mission_v111(p_stage integer,p_mission_id text)returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=aamix_private.lock_rewards(); m jsonb; granted integer; amount integer;
begin
 select value into m from jsonb_array_elements(aamix_private.challenge_missions_v111(p_stage)) where value->>'id'=p_mission_id;
 if m is null then raise exception 'Invalid challenge mission' using errcode='22023';end if;
 if not (m->>'claimed')::boolean then
  if not (m->>'can_claim')::boolean then raise exception 'Mission not complete' using errcode='22023';end if;
  insert into aamix_private.challenge_claims_v111(user_id,stage,mission_id)values(uid,p_stage,p_mission_id) on conflict do nothing returning stage into granted;
  if granted is not null then
   amount:=(m->>'reward_packs')::integer;
   update public.aamix_rewards_state set packs=packs+amount where user_id=uid;
  end if;
 end if;
 return public.aamix_inventory()||jsonb_build_object('reward_packs',coalesce(amount,0));
end$$;
revoke all on function aamix_private.claim_challenge_mission_v111(integer,text) from public,anon,authenticated;
grant execute on function aamix_private.claim_challenge_mission_v111(integer,text) to authenticated;
create function public.aamix_claim_challenge_mission_v111(p_stage integer,p_mission_id text)returns jsonb
language sql security invoker set search_path='' as $$select aamix_private.claim_challenge_mission_v111(p_stage,p_mission_id);$$;
revoke all on function public.aamix_claim_challenge_mission_v111(integer,text) from public,anon,authenticated;
grant execute on function public.aamix_claim_challenge_mission_v111(integer,text) to authenticated;
notify pgrst,'reload schema';
