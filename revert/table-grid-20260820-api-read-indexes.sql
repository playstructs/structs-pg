-- Revert structs-pg:table-grid-20260820-api-read-indexes from pg

BEGIN;

    DROP INDEX IF EXISTS structs.grid_last_action_player_val_id_idx;
    DROP INDEX IF EXISTS structs.grid_attribute_object_val_id_idx;

COMMIT;
