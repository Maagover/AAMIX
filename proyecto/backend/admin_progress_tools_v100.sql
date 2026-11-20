-- ADMINISTRATOR ONLY. Installs recovery tools; this file does not reset progress.
-- Keep the exported backup outside the distributed game archive.
-- Auth identities, email, names, passwords, sessions and UUIDs are never modified.
create schema if not exists aamix_release_backup authorization postgres;
revoke all on schema aamix_release_backup from public,anon,authenticated,service_role;
alter default privileges in schema aamix_release_backup revoke all on tables from public,anon,authenticated,service_role;
alter default privileges in schema aamix_release_backup revoke all on functions from public,anon,authenticated,service_role;

create table aamix_release_backup.batches (
  batch_id uuid primary key default gen_random_uuid(),
  label text not null unique,
  captured_at timestamptz not null default clock_timestamp(),
  user_ids uuid[] not null check(cardinality(user_ids)>0),
  room_ids uuid[] not null,
  opening_ids uuid[] not null,
  auth_fingerprint text not null,
  reset_at timestamptz,
  restored_at timestamptz,
  replaced_by_checkpoint uuid references aamix_release_backup.batches(batch_id)
);
create table aamix_release_backup.table_snapshots (
  batch_id uuid not null references aamix_release_backup.batches(batch_id),
  table_name text not null,
  restore_order integer not null,
  schema_signature text not null,
  predicate_mode text not null check(predicate_mode in('user','rooms','members','commands','corrections')),
  row_count bigint not null check(row_count>=0),
  payload jsonb not null check(jsonb_typeof(payload)='array'),
  payload_md5 text not null,
  primary key(batch_id,table_name),
  unique(batch_id,restore_order)
);
alter table aamix_release_backup.batches enable row level security;
alter table aamix_release_backup.table_snapshots enable row level security;
revoke all on all tables in schema aamix_release_backup from public,anon,authenticated,service_role;

create function aamix_release_backup.require_admin() returns void
language plpgsql security invoker set search_path='' as $$
begin
  if current_user<>'postgres' then raise exception 'Administrator session required' using errcode='42501'; end if;
end $$;

create function aamix_release_backup.auth_fingerprint(p_users uuid[]) returns text
language sql security invoker set search_path='' as $$
  -- Identity checksum only. No Auth credentials or plaintext emails are copied.
  select md5(coalesce(jsonb_agg(jsonb_build_array(u.id,u.email,u.raw_user_meta_data) order by u.id),'[]'::jsonb)::text)
  from auth.users u where u.id=any(p_users);
$$;

create function aamix_release_backup.schema_signature(p_table regclass) returns text
language sql security invoker set search_path='' as $$
  select md5(string_agg(a.attname||':'||pg_catalog.format_type(a.atttypid,a.atttypmod)||':'||a.attnotnull::text||':'||a.attgenerated::text||':'||a.attidentity::text,',' order by a.attnum))
  from pg_catalog.pg_attribute a where a.attrelid=p_table and a.attnum>0 and not a.attisdropped;
$$;

create function aamix_release_backup.predicate_sql(p_mode text) returns text
language plpgsql security invoker set search_path='' as $$
begin
  return case p_mode
    when 'user' then 't.user_id=any($1)'
    when 'rooms' then 't.id=any($2)'
    when 'members' then 't.room_id=any($2)'
    when 'commands' then 't.room_id=any($2)'
    when 'corrections' then 't.opening_id=any($3)'
    else null end;
end $$;

create function aamix_release_backup.capture_rows(p_table regclass,p_mode text,p_users uuid[],p_rooms uuid[],p_openings uuid[]) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb; predicate text:=aamix_release_backup.predicate_sql(p_mode);
begin
  if predicate is null then raise exception 'Unknown snapshot predicate'; end if;
  execute format('select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb) from %s t where %s',p_table,predicate)
    into result using p_users,p_rooms,p_openings;
  return result;
end $$;

create function aamix_release_backup.table_order() returns text[]
language plpgsql security invoker set search_path='' as $$
declare remaining oid[]; result text[]:='{}'; ready oid[]; item oid;
begin
  select array_agg(c.oid order by n.nspname,c.relname) into remaining
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where c.relkind='r' and ((n.nspname='public' and c.relname like 'aamix\_%' escape '\')
    or (n.nspname='aamix_private' and c.relname in('mp_rooms','mp_members','mp_commands','pack_promo_corrections')));
  if cardinality(remaining) is null then raise exception 'No game tables found'; end if;
  if exists(select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where c.oid=any(remaining) and n.nspname='public' and not exists(select 1 from pg_catalog.pg_attribute a where a.attrelid=c.oid and a.attname='user_id' and not a.attisdropped)) then
    raise exception 'A new public AAMIX table needs an explicit snapshot predicate';
  end if;
  if exists(select 1 from pg_catalog.pg_attribute a where a.attrelid=any(remaining) and a.attnum>0 and (a.attgenerated<>'' or a.attidentity<>'')) then
    raise exception 'Generated/identity columns need an explicit restore plan';
  end if;
  while cardinality(remaining)>0 loop
    select array_agg(x order by x) into ready from unnest(remaining) x
    where not exists(select 1 from pg_catalog.pg_constraint f where f.contype='f' and f.conrelid=x and f.confrelid=any(remaining));
    if cardinality(ready) is null then raise exception 'Cyclic game-table foreign keys need an explicit restore plan'; end if;
    foreach item in array ready loop
      result:=array_append(result,item::regclass::text);
      remaining:=array_remove(remaining,item);
    end loop;
  end loop;
  return result;
end $$;

create function aamix_release_backup.lock_tables(p_tables text[]) returns void
language plpgsql security invoker set search_path='' as $$
declare item text;
begin
  foreach item in array p_tables loop
    -- regclass parsing and formatting prevent textual names becoming SQL code.
    execute format('lock table %s in share row exclusive mode',item::regclass);
  end loop;
end $$;

create function aamix_release_backup.capture(p_label text,p_users uuid[] default null) returns uuid
language plpgsql security invoker set search_path='' as $$
declare users uuid[]; rooms uuid[]; openings uuid[]; batch uuid; tables text[]; item text; mode text; payload jsonb; restore_index integer:=0;
begin
  perform aamix_release_backup.require_admin();
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('aamix-v100-progress-reset',0));
  if p_label is null or length(p_label)<8 then raise exception 'A descriptive unique backup label is required'; end if;
  if p_users is null then
    select array_agg(id order by id) into users from auth.users where not(coalesce(raw_user_meta_data,'{}'::jsonb)?'qa_run');
  else
    select array_agg(id order by id) into users from auth.users where id=any(p_users) and not(coalesce(raw_user_meta_data,'{}'::jsonb)?'qa_run');
    if cardinality(users) is distinct from cardinality(p_users) then raise exception 'Recovery users differ from preserved Auth accounts'; end if;
  end if;
  if cardinality(users) is null then raise exception 'No registered non-QA accounts to capture'; end if;
  tables:=aamix_release_backup.table_order();
  perform aamix_release_backup.lock_tables(tables);
  select coalesce(array_agg(id order by id),'{}'::uuid[]) into rooms from aamix_private.mp_rooms r
    where r.host_id=any(users) or r.guest_id=any(users)
      or exists(select 1 from aamix_private.mp_members m where m.room_id=r.id and m.user_id=any(users))
      or exists(select 1 from aamix_private.mp_commands c where c.room_id=r.id and c.sender_id=any(users));
  select coalesce(array_agg(opening_id order by opening_id),'{}'::uuid[]) into openings from public.aamix_pack_openings where user_id=any(users);
  insert into aamix_release_backup.batches(label,user_ids,room_ids,opening_ids,auth_fingerprint)
    values(p_label,users,rooms,openings,aamix_release_backup.auth_fingerprint(users)) returning batch_id into batch;
  foreach item in array tables loop
    restore_index:=restore_index+1;
    mode:=case item when 'aamix_private.mp_rooms' then 'rooms' when 'aamix_private.mp_members' then 'members'
      when 'aamix_private.mp_commands' then 'commands' when 'aamix_private.pack_promo_corrections' then 'corrections' else 'user' end;
    payload:=aamix_release_backup.capture_rows(item::regclass,mode,users,rooms,openings);
    insert into aamix_release_backup.table_snapshots(batch_id,table_name,restore_order,schema_signature,predicate_mode,row_count,payload,payload_md5)
      values(batch,item,restore_index,aamix_release_backup.schema_signature(item::regclass),mode,jsonb_array_length(payload),payload,md5(payload::text));
  end loop;
  return batch;
end $$;

create function aamix_release_backup.verify(p_batch uuid,p_live boolean default true) returns void
language plpgsql security invoker set search_path='' as $$
declare b aamix_release_backup.batches%rowtype; s aamix_release_backup.table_snapshots%rowtype; payload jsonb; tables text[];
begin
  perform aamix_release_backup.require_admin();
  select * into strict b from aamix_release_backup.batches where batch_id=p_batch;
  if aamix_release_backup.auth_fingerprint(b.user_ids)<>b.auth_fingerprint then raise exception 'Auth identities changed: do not overwrite or reset them'; end if;
  tables:=aamix_release_backup.table_order();
  if cardinality(tables)<>(select count(*) from aamix_release_backup.table_snapshots where batch_id=p_batch)
    or exists(select 1 from unnest(tables) t where not exists(select 1 from aamix_release_backup.table_snapshots s where s.batch_id=p_batch and s.table_name=t)) then
    raise exception 'Game table set changed after capture';
  end if;
  for s in select * from aamix_release_backup.table_snapshots where batch_id=p_batch order by restore_order loop
    if md5(s.payload::text)<>s.payload_md5 or jsonb_array_length(s.payload)<>s.row_count then raise exception 'Backup checksum/count mismatch: %',s.table_name; end if;
    if aamix_release_backup.schema_signature(s.table_name::regclass)<>s.schema_signature then raise exception 'Game table structure changed: %',s.table_name; end if;
    if p_live then
      payload:=aamix_release_backup.capture_rows(s.table_name::regclass,s.predicate_mode,b.user_ids,b.room_ids,b.opening_ids);
      if payload<>s.payload then raise exception 'Progress changed after backup: %. Capture and export a fresh batch.',s.table_name; end if;
    end if;
  end loop;
end $$;

create function aamix_release_backup.reset(p_batch uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare b aamix_release_backup.batches%rowtype; s aamix_release_backup.table_snapshots%rowtype; tables text[]; amount bigint; removed bigint:=0; predicate text;
begin
  perform aamix_release_backup.require_admin();
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('aamix-v100-progress-reset',0));
  select * into strict b from aamix_release_backup.batches where batch_id=p_batch for update;
  if b.reset_at is not null or b.restored_at is not null then raise exception 'This batch has already been used; no second reset is allowed'; end if;
  select array_agg(table_name order by restore_order) into tables from aamix_release_backup.table_snapshots where batch_id=p_batch;
  perform aamix_release_backup.lock_tables(tables);
  perform aamix_release_backup.verify(p_batch,true);
  -- Children first, including promotion correction ledger and pack request aliases.
  for s in select * from aamix_release_backup.table_snapshots where batch_id=p_batch order by restore_order desc loop
    predicate:=aamix_release_backup.predicate_sql(s.predicate_mode);
    execute format('delete from %s t where %s',s.table_name::regclass,predicate) using b.user_ids,b.room_ids,b.opening_ids;
    get diagnostics amount=row_count;
    if amount<>s.row_count then raise exception 'Reset affected an unexpected number of rows in %',s.table_name; end if;
    removed:=removed+amount;
  end loop;
  for s in select * from aamix_release_backup.table_snapshots where batch_id=p_batch loop
    if jsonb_array_length(aamix_release_backup.capture_rows(s.table_name::regclass,s.predicate_mode,b.user_ids,b.room_ids,b.opening_ids))<>0 then
      raise exception 'Reset left progress rows in %',s.table_name;
    end if;
  end loop;
  if aamix_release_backup.auth_fingerprint(b.user_ids)<>b.auth_fingerprint then raise exception 'Auth identity checksum changed'; end if;
  update aamix_release_backup.batches set reset_at=clock_timestamp() where batch_id=p_batch;
  return jsonb_build_object('batch_id',p_batch,'accounts',cardinality(b.user_ids),'tables',cardinality(tables),'rows_removed',removed,'auth_unchanged',true,'welcome_awarded',false);
end $$;

create function aamix_release_backup.restore(p_batch uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare b aamix_release_backup.batches%rowtype; s aamix_release_backup.table_snapshots%rowtype; checkpoint uuid; tables text[]; amount bigint; restored bigint:=0;
begin
  perform aamix_release_backup.require_admin();
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('aamix-v100-progress-reset',0));
  select * into strict b from aamix_release_backup.batches where batch_id=p_batch for update;
  if b.reset_at is null or b.restored_at is not null then raise exception 'Batch must have been reset and not restored'; end if;
  select array_agg(table_name order by restore_order) into tables from aamix_release_backup.table_snapshots where batch_id=p_batch;
  perform aamix_release_backup.lock_tables(tables);
  perform aamix_release_backup.verify(p_batch,false);
  -- Preserve any progress earned after the release reset before replacing it.
  checkpoint:=aamix_release_backup.capture('pre-restore-'||p_batch::text||'-'||gen_random_uuid()::text,b.user_ids);
  perform aamix_release_backup.reset(checkpoint);
  -- Parents first. Exact native composite types preserve UUIDs, arrays and JSON.
  for s in select * from aamix_release_backup.table_snapshots where batch_id=p_batch order by restore_order loop
    execute format('insert into %s select * from pg_catalog.jsonb_populate_recordset(null::%s,$1)',s.table_name::regclass,s.table_name::regclass) using s.payload;
    get diagnostics amount=row_count;
    if amount<>s.row_count then raise exception 'Restore affected an unexpected number of rows in %',s.table_name; end if;
    restored:=restored+amount;
  end loop;
  perform aamix_release_backup.verify(p_batch,true);
  update aamix_release_backup.batches set restored_at=clock_timestamp(),replaced_by_checkpoint=checkpoint where batch_id=p_batch;
  return jsonb_build_object('restored_batch',p_batch,'post_reset_progress_checkpoint',checkpoint,'accounts',cardinality(b.user_ids),'rows_restored',restored,'auth_unchanged',true);
end $$;

revoke all on all functions in schema aamix_release_backup from public,anon,authenticated,service_role;
comment on schema aamix_release_backup is 'Administrator-only recoverable AAMIX v1.0 progress snapshots; never expose in Data API or client files.';
