-- Revert structs-pg:view-player from pg

BEGIN;

DROP VIEW IF EXISTS view.player_inventory CASCADE;
DROP VIEW IF EXISTS view.address_inventory CASCADE;
DROP VIEW IF EXISTS view.player CASCADE;

COMMIT;
