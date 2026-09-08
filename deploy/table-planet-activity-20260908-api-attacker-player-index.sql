-- Deploy structs-pg:table-planet-activity-20260908-api-attacker-player-index to pg
--
-- GET /api/planet-activity/player/{id} filters struct_attack rows on
-- detail->>'attackerPlayerId'. A jsonb GIN cannot serve that text equality
-- (it needs detail @>); a btree on the extracted key can, and the cursor
-- suffix matches the existing planet/category/global keyset indexes.
-- Partial: most planet_activity rows are not attacks and have no attacker.
-- TimescaleDB builds each index one chunk at a time to reduce write blocking.

BEGIN;

    CREATE INDEX planet_activity_attacker_player_block_time_planet_seq_idx
        ON structs.planet_activity
        ((detail->>'attackerPlayerId'), block_height DESC NULLS LAST, time DESC, planet_id DESC, seq DESC)
        WITH (timescaledb.transaction_per_chunk)
        WHERE (detail->>'attackerPlayerId') IS NOT NULL;

COMMIT;
