alter table aamix_private.mp_rooms drop constraint mp_rooms_ruleset_version_check;
alter table aamix_private.mp_rooms add constraint mp_rooms_ruleset_version_check check(ruleset_version in('1.2','1.3','1.9'));
