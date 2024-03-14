-- Revert structs-pg:table-grid from pg

BEGIN;

DROP TABLE structs.grid;

COMMIT;
