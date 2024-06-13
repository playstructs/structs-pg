-- Revert structs-pg:view-reactor from pg

BEGIN;

DROP VIEW view.reactor;

COMMIT;
