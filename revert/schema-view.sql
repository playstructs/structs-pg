-- Revert structs-pg:schema-view from pg

BEGIN;

DROP SCHEMA view;

COMMIT;
