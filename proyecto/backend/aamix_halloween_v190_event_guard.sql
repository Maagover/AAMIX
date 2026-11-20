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
end $function$
;
