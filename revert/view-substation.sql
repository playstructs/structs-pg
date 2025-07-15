-- Revert structs-pg:view-substation from pg

BEGIN;

DROP VIEW IF EXISTS view.leaderboard_substation CASCADE;
DROP VIEW IF EXISTS view.substation CASCADE;

COMMIT;
