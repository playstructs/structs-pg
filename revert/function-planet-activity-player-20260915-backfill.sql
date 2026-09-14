-- Revert structs-pg:function-planet-activity-player-20260915-backfill from pg
--
-- Drops the function only. Backfilled rows stay in planet_activity_player;
-- reverting table-planet-activity-player-20260915-attribution removes them.

BEGIN;

    DROP FUNCTION IF EXISTS structs.planet_activity_player_backfill(TIMESTAMPTZ, TIMESTAMPTZ);

COMMIT;
