-- Verify structs-pg:view-planet-20260525-add-name on pg

BEGIN;

    SELECT name FROM view.planet WHERE FALSE;

ROLLBACK;
