-- Revert structs-pg:cagg-planet-activity-player-20260915-daily from pg

BEGIN;

    DROP MATERIALIZED VIEW IF EXISTS structs.planet_activity_player_daily;

COMMIT;
