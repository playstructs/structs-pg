-- Revert structs-pg:view-leaderboard-guild from pg

BEGIN;

DROP VIEW IF EXISTS view.leaderboard_guild CASCADE;

COMMIT;
