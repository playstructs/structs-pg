-- Deploy structs-pg:function-planet-activity-player-20260915-backfill to pg
--
-- Populate structs.planet_activity_player for rows written before the
-- attribution trigger existed. Attribution for historical rows necessarily
-- uses ownership as it is now (the same semantics the webapp applies today);
-- rows written from here on carry ownership as of the event.
--
-- The function is idempotent (ON CONFLICT DO NOTHING) and range-bounded. The
-- deploy runs it once per planet_activity chunk with \gexec, so each week of
-- history is its own transaction instead of one 2.3M-row transaction. Sqitch
-- runs deploy scripts through psql without --single-transaction, so the
-- generated statements commit individually. The function stays available for
-- operators to re-run over any range.

BEGIN;

    CREATE OR REPLACE FUNCTION structs.planet_activity_player_backfill(
        p_from TIMESTAMPTZ,
        p_to   TIMESTAMPTZ
    )
    RETURNS BIGINT
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    DECLARE
        v_inserted BIGINT;
    BEGIN
        WITH ins AS (
            INSERT INTO structs.planet_activity_player
                (time, planet_id, seq, player_id, role, category, block_height)
            SELECT pa.time, pa.planet_id, pa.seq, a.player_id, a.role, pa.category, pa.block_height
              FROM structs.planet_activity pa
              CROSS JOIN LATERAL structs.planet_activity_players(pa.category, pa.planet_id, pa.detail) a
             WHERE pa.time >= p_from AND pa.time < p_to
            ON CONFLICT DO NOTHING
            RETURNING 1
        )
        SELECT count(*) INTO v_inserted FROM ins;

        RETURN v_inserted;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.planet_activity_player_backfill(TIMESTAMPTZ, TIMESTAMPTZ) IS
        'Attribute planet_activity rows in [p_from, p_to) into planet_activity_player using current ownership. Idempotent. Returns rows inserted.';

    GRANT EXECUTE
        ON FUNCTION structs.planet_activity_player_backfill(TIMESTAMPTZ, TIMESTAMPTZ)
        TO structs_indexer;

COMMIT;

-- One statement per existing chunk, oldest first, each in its own transaction.
SELECT format('SELECT %L AS chunk, structs.planet_activity_player_backfill(%L, %L) AS inserted;',
              c.chunk_name, c.range_start, c.range_end)
  FROM timescaledb_information.chunks c
 WHERE c.hypertable_schema = 'structs' AND c.hypertable_name = 'planet_activity'
 ORDER BY c.range_start
\gexec
