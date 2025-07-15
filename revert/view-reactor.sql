-- Revert structs-pg:view-reactor from pg

BEGIN;

DROP VIEW IF EXISTS view.reactor_inventory CASCADE;
DROP VIEW IF EXISTS view.leaderboard_reactor CASCADE;
DROP VIEW IF EXISTS view.reactor CASCADE;

COMMIT;
