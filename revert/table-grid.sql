-- Revert structs-pg:table-grid from pg

BEGIN;

DROP TABLE IF EXISTS structs.grid CASCADE;

COMMIT;
