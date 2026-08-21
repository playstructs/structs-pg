-- Deploy structs-pg:table-planet-activity-20260820-api-read-indexes to pg
--
-- planet_activity.seq is scoped to a planet. These indexes cover the full
-- deterministic cursor tuple used by global, planet, and category feeds.
-- TimescaleDB builds each index one chunk at a time to reduce write blocking.

    CREATE INDEX planet_activity_planet_block_time_seq_idx
        ON structs.planet_activity
        (planet_id, block_height DESC NULLS LAST, time DESC, seq DESC)
        WITH (timescaledb.transaction_per_chunk);

    CREATE INDEX planet_activity_category_block_time_planet_seq_idx
        ON structs.planet_activity
        (category, block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC)
        WITH (timescaledb.transaction_per_chunk);

    CREATE INDEX planet_activity_block_time_planet_seq_idx
        ON structs.planet_activity
        (block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC)
        WITH (timescaledb.transaction_per_chunk);
