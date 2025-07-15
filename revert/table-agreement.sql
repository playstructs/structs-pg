-- Revert structs-pg:table-agreement from pg

BEGIN;

DROP TABLE IF EXISTS structs.agreement CASCADE;

COMMIT;
