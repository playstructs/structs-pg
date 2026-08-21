-- Revert structs-pg:table-planet-activity-20260820-api-cursor-unique from pg

BEGIN;

    DROP INDEX IF EXISTS structs.planet_activity_time_planet_seq_uidx;

COMMIT;
