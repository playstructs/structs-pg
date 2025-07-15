-- Revert structs-pg:trigger-grass-planet-activity from pg

BEGIN;

DROP TRIGGER IF EXISTS PLANET_ACTIVITY_NOTIFY ON structs.planet_activity;
DROP FUNCTION IF EXISTS structs.PLANET_ACTIVITY_NOTIFY();

COMMIT;
