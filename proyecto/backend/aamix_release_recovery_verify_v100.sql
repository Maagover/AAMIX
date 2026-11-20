-- Resolve the table alias distinctly from the PL/pgSQL snapshot record.
create or replace function aamix_release_backup.verify(p_batch uuid,p_live boolean default true) returns void
language plpgsql security invoker set search_path='' as $$
declare b aamix_release_backup.batches%rowtype; s aamix_release_backup.table_snapshots%rowtype; payload jsonb; tables text[];
begin
  perform aamix_release_backup.require_admin();
  select * into strict b from aamix_release_backup.batches where batch_id=p_batch;
  if aamix_release_backup.auth_fingerprint(b.user_ids)<>b.auth_fingerprint then raise exception 'Auth identities changed: do not overwrite or reset them'; end if;
  tables:=aamix_release_backup.table_order();
  if cardinality(tables)<>(select count(*) from aamix_release_backup.table_snapshots where batch_id=p_batch)
    or exists(select 1 from unnest(tables) t where not exists(select 1 from aamix_release_backup.table_snapshots checked where checked.batch_id=p_batch and checked.table_name=t)) then
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

