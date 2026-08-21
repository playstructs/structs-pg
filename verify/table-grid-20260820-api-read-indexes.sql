-- Verify structs-pg:table-grid-20260820-api-read-indexes on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        SELECT pg_get_indexdef(to_regclass('structs.grid_attribute_object_val_id_idx'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE '%(attribute_type, object_type, val, id)%' THEN
            RAISE EXCEPTION 'grid_attribute_object_val_id_idx definition unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.grid_last_action_player_val_id_idx'))
          INTO def;
        IF def IS NULL
           OR def NOT LIKE '%(val, id)%'
           OR def NOT LIKE '%attribute_type%lastAction%'
           OR def NOT LIKE '%object_type%player%' THEN
            RAISE EXCEPTION 'grid_last_action_player_val_id_idx definition unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
