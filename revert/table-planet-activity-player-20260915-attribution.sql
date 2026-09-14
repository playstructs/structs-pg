-- Revert structs-pg:table-planet-activity-player-20260915-attribution from pg

BEGIN;

    DROP TRIGGER IF EXISTS planet_activity_attribute ON structs.planet_activity;
    DROP FUNCTION IF EXISTS structs.planet_activity_attribute();
    DROP TABLE IF EXISTS structs.planet_activity_player;

COMMIT;
