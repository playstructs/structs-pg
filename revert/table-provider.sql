-- Revert structs-pg:table-provider from pg

BEGIN;

DROP TABLE structs.provider;

COMMIT;
