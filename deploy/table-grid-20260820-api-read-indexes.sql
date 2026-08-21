-- Deploy structs-pg:table-grid-20260820-api-read-indexes to pg
--
-- Covers active-player thresholds and other attribute/object/value filters.
-- The partial index keeps the frequent lastAction/player path compact.

BEGIN;

    CREATE INDEX grid_attribute_object_val_id_idx
        ON structs.grid (attribute_type, object_type, val, id);

    CREATE INDEX grid_last_action_player_val_id_idx
        ON structs.grid (val, id)
        WHERE attribute_type = 'lastAction'
          AND object_type = 'player';

COMMIT;
