-- Revert structs-pg:table-planet-activity-20260522-add-block-height from pg

BEGIN;

    ALTER TABLE structs.planet_activity
        DROP COLUMN IF EXISTS block_height;

COMMIT;
