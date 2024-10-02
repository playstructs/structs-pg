-- Revert structs-pg:view-permission from pg

BEGIN;

DROP VIEW view.permission_address;

DROP VIEW view.permission_player;

COMMIT;
