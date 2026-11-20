CREATE OR REPLACE FUNCTION aamix_private.mp_create_room_v190(p_request_id uuid, p_deck_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
select aamix_private.mp_create_room_ruleset(p_request_id,p_deck_id,'1.9');
$function$;
revoke all on function aamix_private.mp_create_room_v190(p_request_id uuid, p_deck_id text) from public,anon,authenticated;
grant execute on function aamix_private.mp_create_room_v190(p_request_id uuid, p_deck_id text) to authenticated;
CREATE OR REPLACE FUNCTION aamix_private.mp_join_room_v190(p_code text, p_deck_id text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
select aamix_private.mp_join_room_ruleset(p_code,p_deck_id,p_request_id,'1.9');
$function$;
revoke all on function aamix_private.mp_join_room_v190(p_code text, p_deck_id text, p_request_id uuid) from public,anon,authenticated;
grant execute on function aamix_private.mp_join_room_v190(p_code text, p_deck_id text, p_request_id uuid) to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_active_v190()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  return aamix_private.mp_active_ruleset('1.9');
end $function$;
revoke all on function public.aamix_mp_active_v190() from public,anon,authenticated;
grant execute on function public.aamix_mp_active_v190() to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_commit_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_host_state jsonb, p_guest_view jsonb, p_actor_slot integer, p_winner integer DEFAULT '-1'::integer, p_error text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.9');
  perform aamix_private.mp_require_snapshot_ruleset(p_host_state,p_guest_view,'1.9');
  return aamix_private.mp_commit(p_room_id,p_request_id,p_expected_revision,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);
end $function$;
revoke all on function public.aamix_mp_commit_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_host_state jsonb, p_guest_view jsonb, p_actor_slot integer, p_winner integer, p_error text) from public,anon,authenticated;
grant execute on function public.aamix_mp_commit_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_host_state jsonb, p_guest_view jsonb, p_actor_slot integer, p_winner integer, p_error text) to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_confirm_v190(p_room_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.9');
  return aamix_private.mp_confirm(p_room_id);
end $function$;
revoke all on function public.aamix_mp_confirm_v190(p_room_id uuid) from public,anon,authenticated;
grant execute on function public.aamix_mp_confirm_v190(p_room_id uuid) to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_create_room_v190(p_request_id uuid, p_deck_id text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
select aamix_private.mp_create_room_v190(p_request_id,p_deck_id);
$function$;
revoke all on function public.aamix_mp_create_room_v190(p_request_id uuid, p_deck_id text) from public,anon,authenticated;
grant execute on function public.aamix_mp_create_room_v190(p_request_id uuid, p_deck_id text) to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_host_action_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_method text, p_args jsonb, p_host_state jsonb, p_guest_view jsonb, p_actor_slot integer, p_winner integer DEFAULT '-1'::integer, p_error text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.9');
  perform aamix_private.mp_require_snapshot_ruleset(p_host_state,p_guest_view,'1.9');
  return aamix_private.mp_host_action(p_room_id,p_request_id,p_expected_revision,p_method,p_args,p_host_state,p_guest_view,p_actor_slot,p_winner,p_error);
end $function$;
revoke all on function public.aamix_mp_host_action_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_method text, p_args jsonb, p_host_state jsonb, p_guest_view jsonb, p_actor_slot integer, p_winner integer, p_error text) from public,anon,authenticated;
grant execute on function public.aamix_mp_host_action_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_method text, p_args jsonb, p_host_state jsonb, p_guest_view jsonb, p_actor_slot integer, p_winner integer, p_error text) to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_join_room_v190(p_code text, p_deck_id text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
select aamix_private.mp_join_room_v190(p_code,p_deck_id,p_request_id);
$function$;
revoke all on function public.aamix_mp_join_room_v190(p_code text, p_deck_id text, p_request_id uuid) from public,anon,authenticated;
grant execute on function public.aamix_mp_join_room_v190(p_code text, p_deck_id text, p_request_id uuid) to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_poll_v190(p_room_id uuid, p_since_revision integer DEFAULT '-1'::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.9');
  return aamix_private.mp_poll(p_room_id,p_since_revision);
end $function$;
revoke all on function public.aamix_mp_poll_v190(p_room_id uuid, p_since_revision integer) from public,anon,authenticated;
grant execute on function public.aamix_mp_poll_v190(p_room_id uuid, p_since_revision integer) to authenticated;
CREATE OR REPLACE FUNCTION public.aamix_mp_submit_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_method text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  perform aamix_private.mp_require_ruleset(p_room_id,'1.9');
  return aamix_private.mp_submit(p_room_id,p_request_id,p_expected_revision,p_method,p_args);
end $function$;
revoke all on function public.aamix_mp_submit_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_method text, p_args jsonb) from public,anon,authenticated;
grant execute on function public.aamix_mp_submit_v190(p_room_id uuid, p_request_id uuid, p_expected_revision integer, p_method text, p_args jsonb) to authenticated;
NOTIFY pgrst,'reload schema';
