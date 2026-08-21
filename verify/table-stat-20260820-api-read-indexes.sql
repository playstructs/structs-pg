-- Verify structs-pg:table-stat-20260820-api-read-indexes on pg

BEGIN;

    DO $$
    DECLARE
        index_name text;
        def text;
    BEGIN
        FOREACH index_name IN ARRAY ARRAY[
            'stat_ore_object_type_index_time_idx',
            'stat_fuel_object_type_index_time_idx',
            'stat_capacity_object_type_index_time_idx',
            'stat_load_object_type_index_time_idx',
            'stat_power_object_type_index_time_idx'
        ]
        LOOP
            SELECT pg_get_indexdef(to_regclass('structs.' || index_name)) INTO def;
            IF def IS NULL
               OR def NOT LIKE '%(object_type, object_index, "time" DESC)%' THEN
                RAISE EXCEPTION '% definition unexpected: %', index_name, def;
            END IF;
        END LOOP;

        FOREACH index_name IN ARRAY ARRAY[
            'stat_structs_load_object_index_time_idx',
            'stat_connection_count_object_index_time_idx',
            'stat_connection_capacity_object_index_time_idx',
            'stat_struct_health_object_index_time_idx',
            'stat_struct_status_object_index_time_idx'
        ]
        LOOP
            SELECT pg_get_indexdef(to_regclass('structs.' || index_name)) INTO def;
            IF def IS NULL
               OR def NOT LIKE '%(object_index, "time" DESC)%' THEN
                RAISE EXCEPTION '% definition unexpected: %', index_name, def;
            END IF;
        END LOOP;
    END
    $$;

ROLLBACK;
