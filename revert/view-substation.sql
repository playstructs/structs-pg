-- Revert structs-pg:view-substation from pg

BEGIN;

DROP VIEW view.substation;

COMMIT;
