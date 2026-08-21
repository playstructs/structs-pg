-- Verify structs-pg:table-planet-activity-20260820-api-read-indexes on pg

BEGIN;

    DO $$
    DECLARE
        def text;
        null_heights bigint;
    BEGIN
        SELECT pg_get_indexdef(to_regclass('structs.planet_activity_planet_block_time_seq_idx'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE '%(planet_id, block_height DESC NULLS LAST, "time" DESC, seq DESC)%' THEN
            RAISE EXCEPTION 'planet activity planet cursor index unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.planet_activity_category_block_time_planet_seq_idx'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE '%(category, block_height DESC NULLS LAST, "time" DESC, planet_id DESC, seq DESC)%' THEN
            RAISE EXCEPTION 'planet activity category cursor index unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.planet_activity_block_time_planet_seq_idx'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE '%(block_height DESC NULLS LAST, "time" DESC, planet_id DESC, seq DESC)%' THEN
            RAISE EXCEPTION 'planet activity global cursor index unexpected: %', def;
        END IF;

        SELECT count(*) INTO null_heights
          FROM structs.planet_activity
         WHERE block_height IS NULL;
        IF null_heights <> 0 THEN
            RAISE EXCEPTION 'planet_activity has % rows without block_height', null_heights;
        END IF;
    END
    $$;

ROLLBACK;
