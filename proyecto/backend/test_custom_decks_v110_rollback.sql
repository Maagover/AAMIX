-- AAMIX 1.1 focused server verification. Synthetic fixtures only; every write rolls back.
-- No email is sent. No real users, balances, inventories or rooms are selected as fixtures.
begin;
set local plpgsql.check_asserts=on;
create temporary table qa110_users(label text primary key,uid uuid default gen_random_uuid());
insert into qa110_users(label) values('a'),('b'),('unconfirmed');
insert into auth.users(id,email,email_confirmed_at,created_at,updated_at,is_anonymous)
  select uid,uid::text||'@qa-v110.invalid',case when label='unconfirmed' then null else now() end,now(),now(),false from qa110_users;
select set_config('qa110.a',(select uid::text from qa110_users where label='a'),true);
select set_config('qa110.b',(select uid::text from qa110_users where label='b'),true);
select set_config('qa110.unconfirmed',(select uid::text from qa110_users where label='unconfirmed'),true);
insert into public.aamix_collection(user_id,code,quantity)
  select uid,code,case when code='0100' then 80 else 4 end from qa110_users cross join aamix_private.reward_catalog where label in('a','b');
insert into public.aamix_owned_decks(user_id,deck_id,name,cover,cards)
  select uid,id,name,cover,cards from qa110_users cross join aamix_private.base_decks where label in('a','b') and id='papito';

set local role authenticated;
do $$
declare r jsonb; old jsonb; saved jsonb; r2 jsonb; pending jsonb; entries jsonb;
  cid text; draft_id text; req uuid:=gen_random_uuid(); match_req uuid:=gen_random_uuid();
  mid uuid; rid uuid; caught boolean; bad jsonb; count_before integer;
begin
  assert (select relrowsecurity from pg_class where oid='public.aamix_custom_decks'::regclass)
    and not has_table_privilege('authenticated','public.aamix_custom_decks','INSERT')
    and not has_table_privilege('authenticated','public.aamix_custom_decks','UPDATE')
    and not has_table_privilege('anon','public.aamix_custom_decks','SELECT')
    and not has_function_privilege('anon','public.aamix_save_custom_deck(uuid,text,text,text,jsonb,boolean,integer)','EXECUTE')
    and not has_function_privilege('authenticated','aamix_private.custom_cards(uuid,jsonb,boolean)','EXECUTE')
    and not has_function_privilege('authenticated','aamix_private.mp_deck(uuid,text)','EXECUTE')
    and not (select prosecdef from pg_proc where oid='public.aamix_save_custom_deck(uuid,text,text,text,jsonb,boolean,integer)'::regprocedure),
    '01 owner RLS, no client writes/internal helpers, public invoker';
  perform set_config('request.jwt.claims','{}',true);
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Vacío','custom_restos','[]',true,0); exception when sqlstate '28000' then caught:=true; end;
  assert caught,'02 no unauthenticated save';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa110.unconfirmed'),'role','authenticated')::text,true);
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Vacío','custom_restos','[]',true,0); exception when sqlstate '28000' then caught:=true; end;
  assert caught,'03 unconfirmed account blocked';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa110.a'),'role','authenticated')::text,true);
  old:=public.aamix_inventory();
  r:=public.aamix_save_custom_deck(req,'','Mi borrador','custom_restos','[]',true,0); saved:=r->'saved_deck'; draft_id:=saved->>'id';
  assert saved->>'revision'='1' and saved->>'custom'='true' and saved->>'draft'='true'
    and saved->'cartas'='[]'::jsonb and r->'saved_deck'=r->'last_saved_deck'
    and r->'decks'=old->'decks' and jsonb_array_length(r->'custom_decks')=1
    and r->'collection'=old->'collection' and r->>'restos'=old->>'restos' and r->>'packs'=old->>'packs',
    '04 empty draft, separate compatible inventory, no inventory/reward mutation';
  r2:=public.aamix_save_custom_deck(req,'','Mi borrador','custom_restos','[]',true,0);
  assert r2->'saved_deck'=saved and jsonb_array_length(r2->'custom_decks')=1,'05 create retry keeps same server deck UUID';
  caught:=false; begin perform public.aamix_save_custom_deck(req,'','Otro','custom_restos','[]',true,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_REQUEST_REUSED'; end;
  assert caught,'06 same request changed payload blocked';
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'papito','Cambio','custom_restos','[]',true,1); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_IMMUTABLE'; end;
  assert caught,'07 base/gift IDs immutable';
  entries:='[{"codigo":"01a","cantidad":3},{"codigo":"0100","cantidad":34},{"codigo":"01c","cantidad":1},{"codigo":"01e","cantidad":1},{"codigo":"01f","cantidad":1}]';
  r:=public.aamix_save_custom_deck(gen_random_uuid(),'','Promocionales','custom_transmision',entries,false,0);
  cid:=r->'saved_deck'->>'id'; saved:=r->'saved_deck';
  assert saved->>'draft'='false' and saved->>'revision'='1' and saved->'cartas'->0->>'codigo'='0100'
    and jsonb_array_length(saved->'cartas')=5,'08 playable40, resource34, promotional Singular1, canonical sorting';
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),cid,'Desfase','custom_restos',entries,false,0); exception when sqlstate '40001' then caught:=sqlerrm='AAMIX_DECK_REVISION_CONFLICT'; end;
  assert caught,'09 stale revision rejected';
  foreach bad in array array[
    '[{"codigo":"0101","cantidad":4}]'::jsonb,
    '[{"codigo":"0103","cantidad":2}]'::jsonb,
    '[{"codigo":"01c","cantidad":2}]'::jsonb,
    '[{"codigo":"01e","cantidad":2}]'::jsonb,
    '[{"codigo":"01f","cantidad":2}]'::jsonb
  ] loop
    caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Límite','custom_restos',bad,true,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_COPY_LIMIT'; end;
    assert caught,'10 ordinary3/Singular1 includes promos';
  end loop;
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Grande','custom_restos','[{"codigo":"0100","cantidad":41}]',true,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_TOO_LARGE'; end;
  assert caught,'11 draft total above40 rejected';
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Incompleto','custom_restos','[{"codigo":"0100","cantidad":39}]',false,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_SIZE'; end;
  assert caught,'12 final39 rejected';
  -- Literal40 cards without resources; all are legal ordinary card types.
  bad:='[{"codigo":"0101","cantidad":3},{"codigo":"0102","cantidad":3},{"codigo":"0104","cantidad":3},{"codigo":"0106","cantidad":3},{"codigo":"0107","cantidad":3},{"codigo":"0108","cantidad":3},{"codigo":"0109","cantidad":3},{"codigo":"0110","cantidad":3},{"codigo":"0111","cantidad":3},{"codigo":"0112","cantidad":3},{"codigo":"0113","cantidad":3},{"codigo":"0114","cantidad":3},{"codigo":"0116","cantidad":3},{"codigo":"0117","cantidad":1}]';
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Sin Restos','custom_restos',bad,false,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_INITIAL_RESOURCE'; end;
  assert caught,'13 final40 needs initial Restos';
  foreach bad in array array[
    '[{"codigo":"0101","cantidad":0}]'::jsonb,
    '[{"codigo":"0101","cantidad":-1}]'::jsonb,
    '[{"codigo":"0101","cantidad":1.5}]'::jsonb,
    '[{"codigo":"0101","cantidad":"1"}]'::jsonb,
    '[{"codigo":"0101","cantidad":1,"extra":true}]'::jsonb,
    '[{"codigo":"missing","cantidad":1}]'::jsonb,
    '[{"codigo":"0101","cantidad":1},{"codigo":"0101","cantidad":1}]'::jsonb
  ] loop
    caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Inválido','custom_restos',bad,true,0); exception when sqlstate '22023' then caught:=true; end;
    assert caught,'14 malformed, unknown and duplicate entries rejected';
  end loop;
  caught:=false; begin perform public.aamix_begin_match(gen_random_uuid(),draft_id); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_DRAFT'; end;
  assert caught,'15 draft blocked in single';
  caught:=false; begin perform public.aamix_begin_challenge_match(gen_random_uuid(),draft_id,1); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_DRAFT'; end;
  assert caught,'16 draft blocked in challenge';
  caught:=false; begin perform public.aamix_mp_create_room(gen_random_uuid(),draft_id); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_DRAFT'; end;
  assert caught,'17 draft blocked in multiplayer';
  pending:=public.aamix_begin_match(match_req,cid); mid:=(pending->>'match_id')::uuid;
  assert pending->'match_deck'=saved,'18 single starts from exact server snapshot';
  r:=public.aamix_save_custom_deck(gen_random_uuid(),cid,'Editado','custom_restos','[{"codigo":"0100","cantidad":40}]',false,1);
  assert r->'saved_deck'->>'revision'='2' and r->'saved_deck'->>'nombre'='Editado','19 custom deck editable with revision';
  pending:=public.aamix_begin_match(match_req,cid);
  assert pending->'match_deck'=saved and pending->>'match_id'=mid::text,'20 retry freezes deck revision1 after edit';
  pending:=public.aamix_begin_challenge_match(gen_random_uuid(),cid,1);
  assert pending->'match_deck'->>'revision'='2' and pending->'challenge_opponent'->>'id'='papito','21 challenge accepts custom40';
  r:=public.aamix_mp_create_room(gen_random_uuid(),cid); rid:=(r->>'room_id')::uuid;
  perform set_config('qa110.room',rid::text,true);
  perform set_config('qa110.code',r->>'code',true);
  perform set_config('qa110.custom',cid,true);
  assert r->'host_deck'->>'revision'='2' and r->'protocol'='3'::jsonb,'22 multiplayer creates compatible frozen snapshot';
  r:=public.aamix_save_custom_deck(gen_random_uuid(),cid,'En construcción','custom_restos','[]',true,2);
  r2:=public.aamix_mp_poll(rid,-1);
  assert r2->'host_deck'->>'revision'='2' and r2->'host_deck'->>'draft'='false','23 editing active room deck leaves frozen copy playable';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('qa110.b'),'role','authenticated')::text,true);
  assert not exists(select 1 from public.aamix_custom_decks) and public.aamix_inventory()->'custom_decks'='[]'::jsonb,'24 owner RLS/inventory isolation';
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),cid,'Robo','custom_restos','[]',true,3); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_UNOWNED_DECK'; end;
  assert caught,'25 other UUID cannot edit';
  caught:=false; begin perform public.aamix_begin_match(gen_random_uuid(),cid); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_UNOWNED_DECK'; end;
  assert caught,'26 other UUID cannot play';
  pending:=public.aamix_mp_join_room(current_setting('qa110.code'),'papito',gen_random_uuid());
  assert pending->>'status'='ready' and not(pending?'host_deck') and not(pending?'guest_deck'),'27 guest cannot receive rival deck list';
end $$;
reset role;
-- Owned-copy checks use only a synthetic account inventory adjustment inside this transaction.
update public.aamix_collection set quantity=1 where user_id=current_setting('qa110.b')::uuid and code in('0100','0101');
set local role authenticated;
do $$
declare caught boolean; r jsonb;
begin
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Copias ajenas','custom_restos','[{"codigo":"0101","cantidad":2}]',true,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_UNOWNED_COPIES'; end;
  assert caught,'28 normal cannot exceed copies owned';
  caught:=false; begin perform public.aamix_save_custom_deck(gen_random_uuid(),'','Restos ajenos','custom_restos','[{"codigo":"0100","cantidad":2}]',true,0); exception when sqlstate '22023' then caught:=sqlerrm='AAMIX_DECK_UNOWNED_COPIES'; end;
  assert caught,'29 Resource unlimited by rule still capped by inventory';
  r:=public.aamix_begin_match(gen_random_uuid(),'papito');
  assert r->'match_deck'->>'id'='papito' and not(r->'match_deck'?'custom'),'30 v1.0 base gameplay compatible';
end $$;
reset role;
-- Multiplayer finish uses the existing rules host; only immutable snapshots/receipt accounting is checked.
update aamix_private.mp_rooms set started_at=now(),status='playing' where id=current_setting('qa110.room')::uuid;
select aamix_private.mp_finish(current_setting('qa110.room')::uuid,0,'qa_v110');
select aamix_private.mp_finish(current_setting('qa110.room')::uuid,0,'qa_v110_retry');
do $$
begin
  assert (select count(*) from public.aamix_match_receipts where online_room_id=current_setting('qa110.room')::uuid)=2
    and (select player_deck->>'revision' from public.aamix_match_receipts where online_room_id=current_setting('qa110.room')::uuid and user_id=current_setting('qa110.a')::uuid)='2',
    '31 immutable multiplayer snapshot and one receipt per participant on repeated finish';
end $$;
select jsonb_build_object('status','passed','groups',31,'random_draws',0,'synthetic_accounts',3,'writes','transaction rolls back next') as verification;
rollback;

