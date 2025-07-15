-- Revert structs-pg:table-provider from pg

BEGIN;

DROP TABLE IF EXISTS structs.provider CASCADE;

COMMIT;
