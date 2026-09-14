-- Verify structs-pg:index-planet-activity-20260915-drop-time-idx on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regclass('structs.planet_activity_time_idx') IS NOT NULL THEN
            RAISE EXCEPTION 'planet_activity_time_idx still exists';
        END IF;
        IF to_regclass('structs.planet_activity_time_planet_seq_uidx') IS NULL THEN
            RAISE EXCEPTION 'planet_activity_time_planet_seq_uidx must exist to cover time lookups';
        END IF;
    END
    $$;

ROLLBACK;
