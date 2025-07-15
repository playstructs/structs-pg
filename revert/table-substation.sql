-- Revert structs-pg:table-substation from pg

BEGIN;

DROP TABLE IF EXISTS structs.substation CASCADE;

COMMIT;
