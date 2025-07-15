-- Revert structs-pg:trigger-grass-grid from pg

BEGIN;

DROP TRIGGER IF EXISTS GRID_NOTIFY ON structs.grid;
DROP FUNCTION IF EXISTS structs.GRID_NOTIFY();

COMMIT;
