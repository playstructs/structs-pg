-- Revert structs-pg:view-planet from pg

BEGIN;

DROP VIEW view.planet;

COMMIT;
