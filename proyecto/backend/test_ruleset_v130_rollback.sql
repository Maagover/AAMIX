-- Focused 1.3 room compatibility checks; existing game rules/economy are not exercised.
-- Synthetic users only; all writes and test rooms roll back. No email, random draws or rewards.
begin;
set local plpgsql.check_asserts=on;
create temporary table qa130_ruleset(label text primary key,uid uuid not null default gen_random_uuid());
insert into qa130_ruleset(label) values('host'),('guest');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@qa-ruleset-v130.invalid',now(),now(),now(),false from qa130_ruleset;
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select q.uid,d.id,d.name,d.cover,d.cards from qa130_ruleset q cross join aamix_private.base_decks d where d.id in('papito','flaan');
select set_config('qa130.host',(select uid::text from qa130_ruleset where label='host'),true);
select set_config('qa130.guest',(select uid::text from qa130_ruleset where label='guest'),true);

set local role authenticated;
do $$
declare r jsonb; g jsonb; old jsonb; caught boolean; rid uuid; legacy_id uuid; rejected integer:=0;
  create_request uuid:=gen_random_uuid(); legacy_request uuid:=gen_random_uuid(); join_request uuid:=gen_random_uuid();
  h jsonb:='{"protocol":1,"ruleset_version":"1.3","players":[{"deck":[4],"hand":[3]},{"deck":[6],"hand":[5]}],"instances":{"3":{"code":"0115"},"4":{"code":"0103"},"5":{"code":"0107"},"6":{"code":"0105"}},"actor":0,"winner":-1,"queue":[],"log_lines":[],"rng_seed":"123","rng_state":"456","pending":{}}';
  v jsonb:='{"protocol":1,"ruleset_version":"1.3","players":[{"deck":[-1000],"hand":[-3000]},{"deck":[-1100],"hand":[5]}],"instances":{"5":{"code":"0107"},"-1000":{"code":"0100"},"-1100":{"code":"0100"},"-3000":{"code":"0100"}},"actor":0,"winner":-1,"queue":[],"log_lines":[],"rng_seed":"0","rng_state":"0","pending":{}}';
begin
  assert not has_function_privilege('anon','public.aamix_mp_create_room_v130(uuid,text)','EXECUTE')
    and not has_function_privilege('anon','public.aamix_mp_join_room_v130(text,text,uuid)','EXECUTE')
    and not has_function_privilege('authenticated','aamix_private.mp_create_room_ruleset(uuid,text,text)','EXECUTE')
    and not has_function_privilege('authenticated','aamix_private.mp_join_room_ruleset(text,text,uuid,text)','EXECUTE')
    and not (select prosecdef from pg_proc where oid='public.aamix_mp_create_room_v130(uuid,text)'::regprocedure),
    '01 guarded new invoker endpoints, internal helpers denied';
  perform set_config('request.jwt.claims','{}',true);
  caught:=false; begin perform public.aamix_mp_create_room_v130(create_request,'papito'); exception when sqlstate '28000' then caught:=true; end;
  assert caught,'02 identity still required';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa130.host'),'role','authenticated')::text,true);
  r:=public.aamix_mp_create_room(legacy_request,'papito'); legacy_id:=(r->>'room_id')::uuid;
  assert r->>'ruleset_version'='1.2' and r->>'protocol'='3' and r->>'status'='waiting',
    '03 old create signature defaults to legacy rules and same transport';
  perform set_config('qa130.legacy',legacy_id::text,true);
  caught:=false; begin perform public.aamix_mp_create_room_v130(legacy_request,'papito'); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught and public.aamix_mp_create_room(legacy_request,'papito')->>'room_id'=legacy_id::text,
    '04 create UUID cannot be replayed across rulesets';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa130.guest'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_mp_join_room_v130(r->>'code','papito',join_request); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught and public.aamix_mp_active()->>'room_id' is null,'05 new client cannot enter legacy room or leave partial membership';
  g:=public.aamix_mp_join_room(r->>'code','flaan',join_request);
  assert g->>'ruleset_version'='1.2' and g->>'status'='ready' and not(g?'host_deck') and not(g?'guest_deck') and not(g?'commands'),
    '06 old clients still join each other with private views';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa130.host'),'role','authenticated')::text,true);
  g:=public.aamix_mp_active_v130();
  assert g->>'incompatible'='true' and g->>'ruleset_version'='1.2' and g->>'room_id'=legacy_id::text
    and not(g?'state') and not(g?'host_deck') and not(g?'guest_deck') and not(g?'commands') and not(g?'players'),
    '18 new reconnect exposes only old-room metadata for closure';
  caught:=false; begin perform public.aamix_mp_poll_v130(legacy_id,-1); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught,'19 new operations cannot resume legacy room';
  perform aamix_private.mp_require_snapshot_ruleset(h-'ruleset_version',v-'ruleset_version','1.2');
  caught:=false; begin perform public.aamix_mp_commit(legacy_id,gen_random_uuid(),0,h,v,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught,'20 legacy snapshots may omit version but cannot write explicit new version';
  perform public.aamix_mp_leave(legacy_id);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa130.host'),'role','authenticated')::text,true);
  r:=public.aamix_mp_create_room_v130(create_request,'papito'); rid:=(r->>'room_id')::uuid;
  perform set_config('qa130.new',rid::text,true);
  assert r->>'ruleset_version'='1.3' and r->>'protocol'='3' and r->>'revision'='0'
    and public.aamix_mp_create_room_v130(create_request,'papito')->>'room_id'=rid::text,
    '07 new room and create retry retain rules, UUID and revision';
  caught:=false; begin perform public.aamix_mp_create_room(create_request,'papito'); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught,'08 legacy create cannot replay a new room';
  old:=r;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa130.guest'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_mp_join_room(r->>'code','papito',join_request); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught and public.aamix_mp_active()->>'room_id' is null,'09 legacy client cannot enter new room or leave partial membership';
  g:=public.aamix_mp_join_room_v130(lower(r->>'code'),'flaan',join_request);
  assert g->>'ruleset_version'='1.3' and g->>'slot'='1' and g->>'status'='ready'
    and not(g?'host_deck') and not(g?'guest_deck') and not(g?'commands'),
    '10 compatible new join retains privacy';
  assert public.aamix_mp_join_room_v130(r->>'code','flaan',join_request)->>'room_id'=rid::text,'11 compatible join replay is idempotent';
  caught:=false; begin perform public.aamix_mp_join_room(r->>'code','flaan',join_request); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught,'12 legacy join cannot replay a new membership';
  caught:=false; begin perform public.aamix_mp_join_room_v130(r->>'code','papito',join_request); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_REQUEST_REUSED'; end;
  assert caught,'13 join UUID still binds frozen deck';
  caught:=false; begin perform public.aamix_mp_active(); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught,'21 legacy reconnect cannot receive a new ruleset snapshot after downgrade';
  g:=public.aamix_mp_confirm_v130(rid);
  assert g->>'ruleset_version'='1.3' and public.aamix_mp_active_v130()->>'room_id'=rid::text,
    '14 confirm/active response carries rules without changing reconnect contract';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa130.host'),'role','authenticated')::text,true);
  r:=public.aamix_mp_poll_v130(rid,-1);
  assert r->>'ruleset_version'='1.3' and r->>'revision'='0' and r->'guest_deck'->>'id'='flaan'
    and (r->>'room_version')::bigint>(old->>'room_version')::bigint,'15 poll keeps ordered room version and frozen decks';
  perform public.aamix_mp_confirm_v130(rid);
  caught:=false; begin perform public.aamix_mp_commit_v130(rid,gen_random_uuid(),0,h-'ruleset_version',v-'ruleset_version',0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_RULESET_MISMATCH'; end;
  assert caught,'22 new commits require explicitly versioned snapshots';
  r:=public.aamix_mp_commit_v130(rid,gen_random_uuid(),0,h,v,0);
  assert r->>'ruleset_version'='1.3' and r->>'status'='playing' and r->>'revision'='1'
    and r->'state'->>'ruleset_version'='1.3','16 snapshot extra rules field accepted and normal commit preserved';
  rejected:=0;
  begin perform public.aamix_mp_poll(rid,-1); exception when sqlstate '22023' then if sqlerrm='AAMIX_RULESET_MISMATCH' then rejected:=rejected+1; end if; end;
  begin perform public.aamix_mp_confirm(rid); exception when sqlstate '22023' then if sqlerrm='AAMIX_RULESET_MISMATCH' then rejected:=rejected+1; end if; end;
  begin perform public.aamix_mp_submit(rid,gen_random_uuid(),1,'keep_hand','[]'); exception when sqlstate '22023' then if sqlerrm='AAMIX_RULESET_MISMATCH' then rejected:=rejected+1; end if; end;
  begin perform public.aamix_mp_commit(rid,gen_random_uuid(),1,h,v,0); exception when sqlstate '22023' then if sqlerrm='AAMIX_RULESET_MISMATCH' then rejected:=rejected+1; end if; end;
  begin perform public.aamix_mp_host_action(rid,gen_random_uuid(),1,'keep_hand','[]',h,v,0); exception when sqlstate '22023' then if sqlerrm='AAMIX_RULESET_MISMATCH' then rejected:=rejected+1; end if; end;
  assert rejected=5 and public.aamix_mp_poll_v130(rid,-1)->>'revision'='1',
    '23 every legacy gameplay operation rejects a new room without committing or changing revision';
  r:=public.aamix_mp_submit_v130(rid,gen_random_uuid(),1,'keep_hand','[]');
  assert jsonb_array_length(r->'commands')=1,'24 compatible new command submission preserves the existing queue';
end $$;
reset role;
do $$
begin
  assert (select count(*) from aamix_private.mp_members where user_id in(current_setting('qa130.host')::uuid,current_setting('qa130.guest')::uuid))=2
    and (select ruleset_version from aamix_private.mp_rooms where id=current_setting('qa130.legacy')::uuid)='1.2'
    and (select ruleset_version from aamix_private.mp_rooms where id=current_setting('qa130.new')::uuid)='1.3'
    and not exists(select 1 from public.aamix_match_receipts where user_id in(current_setting('qa130.host')::uuid,current_setting('qa130.guest')::uuid)),
    '17 only final compatible memberships, no reward receipts during setup';
end $$;
select jsonb_build_object('status','passed','groups',24,'synthetic_accounts',2,'random_draws',0,'writes','transaction rolls back next') as verification;
rollback;

