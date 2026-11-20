-- OPTIONAL RECOVERY ONLY. Do not run as part of the v1.0 release.
-- Restores the exact pre-release progress for captured UUIDs, never Auth.
-- Automatically captures any post-reset progress first, so restoration can itself
-- be undone by restoring the returned checkpoint UUID. Unique/FK conflicts abort
-- the whole transaction rather than overwrite another player's unrelated data.
begin;
set local lock_timeout='8s';
set local statement_timeout='60s';
select aamix_release_backup.restore((select batch_id from aamix_release_backup.batches
  where label='aamix-v1.0-official-progress-reset-2026-10-19')) as restore_result;
commit;
