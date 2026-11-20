-- Run only after capturing, verifying and exporting the recoverable backup.
-- This is the user-authorized one-time official-release progress reset.
-- Only captured UUIDs are affected. Auth accounts and identities are preserved.
-- No welcome rewards are awarded here: the next login uses normal bootstrap.
begin;
set local lock_timeout='8s';
set local statement_timeout='60s';
select aamix_release_backup.reset((select batch_id from aamix_release_backup.batches
  where label='aamix-v1.0-official-progress-reset-2026-10-19')) as reset_result;
commit;
