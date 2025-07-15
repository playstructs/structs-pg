-- Revert structs-pg:view-work from pg

BEGIN;

DROP VIEW IF EXISTS view.work CASCADE;

COMMIT;
