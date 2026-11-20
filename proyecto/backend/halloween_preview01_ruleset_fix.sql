-- Only the new preview room table; official room constraints are untouched.
alter table aamix_hw01_private.mp_rooms drop constraint mp_rooms_ruleset_version_check;
alter table aamix_hw01_private.mp_rooms add constraint mp_rooms_ruleset_version_check check(ruleset_version='1.9-halloween-preview1');
alter table aamix_hw01_private.mp_rooms alter column ruleset_version set default '1.9-halloween-preview1';
