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
