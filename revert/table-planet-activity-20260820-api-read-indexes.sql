-- Revert structs-pg:table-planet-activity-20260820-api-read-indexes from pg

BEGIN;

    DROP INDEX IF EXISTS structs.planet_activity_block_time_planet_seq_idx;
    DROP INDEX IF EXISTS structs.planet_activity_category_block_time_planet_seq_idx;
    DROP INDEX IF EXISTS structs.planet_activity_planet_block_time_seq_idx;

COMMIT;
