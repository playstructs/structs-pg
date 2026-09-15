-- Revert structs-pg:index-planet-activity-20260915-drop-feed-indexes from pg
--
-- Recreates both indexes as originally defined
-- (table-planet-activity-20260820-api-read-indexes,
-- table-planet-activity-20260909-api-struct-attack-gin). Without
-- transaction_per_chunk: Timescale 2.29+ rejects it inside a transaction.

BEGIN;

    CREATE INDEX planet_activity_block_time_planet_seq_idx
        ON structs.planet_activity
        (block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC);

    CREATE INDEX planet_activity_detail_gin
        ON structs.planet_activity
        USING gin (detail jsonb_path_ops)
        WHERE category = 'struct_attack';

COMMIT;
