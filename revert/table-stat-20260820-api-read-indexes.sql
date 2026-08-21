-- Revert structs-pg:table-stat-20260820-api-read-indexes from pg

BEGIN;

    DROP INDEX IF EXISTS structs.stat_struct_status_object_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_struct_health_object_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_connection_capacity_object_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_connection_count_object_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_structs_load_object_index_time_idx;

    DROP INDEX IF EXISTS structs.stat_power_object_type_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_load_object_type_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_capacity_object_type_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_fuel_object_type_index_time_idx;
    DROP INDEX IF EXISTS structs.stat_ore_object_type_index_time_idx;

COMMIT;
