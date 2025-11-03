-- Revert structs-pg:view-leaderboard-player from pg

BEGIN;

DROP VIEW IF EXISTS view.leaderboard_player CASCADE;

COMMIT;
