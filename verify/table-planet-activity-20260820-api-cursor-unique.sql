-- Verify structs-pg:table-planet-activity-20260820-api-cursor-unique on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        SELECT pg_get_indexdef(to_regclass('structs.planet_activity_time_planet_seq_uidx'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE 'CREATE UNIQUE INDEX %("time", planet_id, seq)%' THEN
            RAISE EXCEPTION 'planet activity unique key index unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
