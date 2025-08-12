-- Revert structs-pg:table-tmp-try from pg

BEGIN;

DROP TABLE IF EXISTS structs.tmp_try CASCADE;

COMMIT;
