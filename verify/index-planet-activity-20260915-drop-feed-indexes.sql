-- Verify structs-pg:index-planet-activity-20260915-drop-feed-indexes on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regclass('structs.planet_activity_block_time_planet_seq_idx') IS NOT NULL
           OR to_regclass('structs.planet_activity_detail_gin') IS NOT NULL THEN
            RAISE EXCEPTION 'feed indexes still present on structs.planet_activity';
        END IF;
        -- the indexes the remaining endpoints depend on must still be there
        IF to_regclass('structs.planet_activity_time_planet_seq_uidx') IS NULL
           OR to_regclass('structs.planet_activity_planet_block_time_seq_idx') IS NULL
           OR to_regclass('structs.planet_activity_category_block_time_planet_seq_idx') IS NULL THEN
            RAISE EXCEPTION 'expected planet_activity read indexes are missing';
        END IF;
    END
    $$;

ROLLBACK;
