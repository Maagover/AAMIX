-- Run once as postgres after installing admin_progress_tools_v100.sql.
-- This captures all existing non-QA account UUIDs, including unconfirmed signups.
-- Auth is read only; public game data and associated private rooms are captured.
begin;
set local lock_timeout='8s';
set local statement_timeout='60s';
select aamix_release_backup.capture('aamix-v1.0-official-progress-reset-2026-10-19') as batch_id;
commit;
-- Export this JSON outside the game package BEFORE running the reset file.
select jsonb_build_object('batch',to_jsonb(b),'tables',(
  select jsonb_agg(to_jsonb(s) order by s.restore_order) from aamix_release_backup.table_snapshots s where s.batch_id=b.batch_id
)) as recoverable_backup from aamix_release_backup.batches b where b.label='aamix-v1.0-official-progress-reset-2026-10-19';
