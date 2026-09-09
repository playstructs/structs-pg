-- Deploy structs-pg:table-planet-activity-20260909-api-struct-attack-gin to pg
--
-- GET /api/planet-activity/player/{id} struct_attack half:
--   detail @> jsonb_build_object('attackerPlayerId', :player_id)
--   OR detail @> jsonb_build_object(
--        'eventAttackShotDetail',
--        jsonb_build_array(jsonb_build_object('targetPlayerId', :player_id))
--      )
-- Both @> halves are required. Without an index Postgres plans a scan of
-- every hypertable chunk (~264 ms planning alone on 24 chunks).
--
-- jsonb_path_ops (not default GIN): this query only uses @>, and path_ops
-- is smaller/faster for that. Partial on category = 'struct_attack' (~2,721
-- rows). Timescale builds one chunk at a time; CONCURRENTLY is not used
-- because hypertables reject it and Sqitch runs inside a transaction.
--
-- handle_event_attack stores the EventAttack payload as detail. Attacker
-- id is top-level attackerPlayerId; targetPlayerId moved onto each
-- eventAttackShotDetail[] entry (structsd proto, API-breaking).
--
-- Replaces planet_activity_attacker_player_block_time_planet_seq_idx, which
-- cannot serve the nested @> half.

BEGIN;

    DROP INDEX IF EXISTS structs.planet_activity_attacker_player_block_time_planet_seq_idx;

    CREATE INDEX planet_activity_detail_gin
        ON structs.planet_activity
        USING gin (detail jsonb_path_ops)
        WITH (timescaledb.transaction_per_chunk)
        WHERE category = 'struct_attack';

COMMIT;
