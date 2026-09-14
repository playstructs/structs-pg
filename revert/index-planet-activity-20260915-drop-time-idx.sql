-- Revert structs-pg:index-planet-activity-20260915-drop-time-idx from pg

BEGIN;

    CREATE INDEX planet_activity_time_idx ON structs.planet_activity (time DESC);

COMMIT;
