-- Revert structs-pg:table-reactor from pg

BEGIN;

DROP TABLE IF EXISTS structs.reactor CASCADE;

COMMIT;
