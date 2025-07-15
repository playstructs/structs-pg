-- Revert structs-pg:view-planet from pg

BEGIN;

DROP VIEW IF EXISTS view.planet CASCADE;

COMMIT;
