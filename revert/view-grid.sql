-- Revert structs-pg:view-grid from pg

BEGIN;

DROP VIEW IF EXISTS view.leaderboard_provider CASCADE;
DROP VIEW IF EXISTS view.grid CASCADE;

COMMIT;
