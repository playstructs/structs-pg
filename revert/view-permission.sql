-- Revert structs-pg:view-permission from pg

BEGIN;

DROP VIEW IF EXISTS view.permission_player CASCADE;
DROP VIEW IF EXISTS view.permission_address CASCADE;

COMMIT;
