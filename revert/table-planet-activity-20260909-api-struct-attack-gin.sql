-- Revert structs-pg:table-planet-activity-20260909-api-struct-attack-gin from pg

BEGIN;

    DROP INDEX IF EXISTS structs.planet_activity_detail_gin;

    CREATE INDEX planet_activity_attacker_player_block_time_planet_seq_idx
        ON structs.planet_activity
        ((detail->>'attackerPlayerId'), block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC)
        WITH (timescaledb.transaction_per_chunk)
        WHERE (detail->>'attackerPlayerId') IS NOT NULL;

COMMIT;
