-- Revert structs-pg:view-work-20260914-read-api-current-state from pg
--
-- Back to the live computation; structs.api_work is left in place.

BEGIN;

    CREATE OR REPLACE VIEW view.work AS
        SELECT object_id, player_id, target_id, category, block_start,
               difficulty_target, location_type, location_id, planet_id
          FROM view.work_live;

    COMMENT ON VIEW view.work IS NULL;

COMMIT;
