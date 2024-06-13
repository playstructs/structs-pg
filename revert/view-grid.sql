-- Revert structs-pg:view-grid from pg

BEGIN;

DROP VIEW view.grid;

COMMIT;
