-- Deploy structs-pg:table-stat-20260820-api-read-indexes to pg
--
-- Supports pre-range seed and in-range scans for bucket-close LOCF rollups.
-- TimescaleDB builds each index one chunk at a time to reduce write blocking.

    CREATE INDEX stat_ore_object_type_index_time_idx
        ON structs.stat_ore (object_type, object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_fuel_object_type_index_time_idx
        ON structs.stat_fuel (object_type, object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_capacity_object_type_index_time_idx
        ON structs.stat_capacity (object_type, object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_load_object_type_index_time_idx
        ON structs.stat_load (object_type, object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_power_object_type_index_time_idx
        ON structs.stat_power (object_type, object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);

    CREATE INDEX stat_structs_load_object_index_time_idx
        ON structs.stat_structs_load (object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_connection_count_object_index_time_idx
        ON structs.stat_connection_count (object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_connection_capacity_object_index_time_idx
        ON structs.stat_connection_capacity (object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_struct_health_object_index_time_idx
        ON structs.stat_struct_health (object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
    CREATE INDEX stat_struct_status_object_index_time_idx
        ON structs.stat_struct_status (object_index, time DESC)
        WITH (timescaledb.transaction_per_chunk);
