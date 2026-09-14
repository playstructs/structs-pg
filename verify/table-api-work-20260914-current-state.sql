-- Verify structs-pg:table-api-work-20260914-current-state on pg

BEGIN;

    SELECT object_id, player_id, target_id, category, block_start,
           difficulty_target, location_type, location_id, planet_id,
           source_height, updated_at
      FROM structs.api_work WHERE FALSE;

    DO $$
    DECLARE
        object_name text;
        mismatched  text;
    BEGIN
        FOREACH object_name IN ARRAY ARRAY[
            'api_work_player_idx',
            'api_work_planet_idx',
            'api_work_category_idx'
        ]
        LOOP
            IF to_regclass('structs.' || object_name) IS NULL THEN
                RAISE EXCEPTION 'expected structs.% to exist', object_name;
            END IF;
        END LOOP;

        -- Every view.work column must exist on api_work with the same type so
        -- the view can be re-pointed at the table later.
        SELECT string_agg(v.column_name || ' ' || v.data_type, ', ') INTO mismatched
          FROM information_schema.columns v
          LEFT JOIN information_schema.columns t
            ON t.table_schema = 'structs'
           AND t.table_name = 'api_work'
           AND t.column_name = v.column_name
           AND t.data_type = v.data_type
         WHERE v.table_schema = 'view'
           AND v.table_name = 'work'
           AND t.column_name IS NULL;
        IF mismatched IS NOT NULL THEN
            RAISE EXCEPTION 'structs.api_work does not match view.work columns: %', mismatched;
        END IF;
    END
    $$;

ROLLBACK;
