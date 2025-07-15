-- Revert structs-pg:table-fleet from pg

BEGIN;

DROP TABLE IF EXISTS structs.fleet CASCADE;

COMMIT;
