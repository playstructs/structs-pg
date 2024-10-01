-- Revert structs-pg:view-work from pg

BEGIN;

DROP VIEW view.work;

COMMIT;
