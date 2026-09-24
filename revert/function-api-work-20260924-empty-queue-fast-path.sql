-- Revert structs-pg:function-api-work-20260924-empty-queue-fast-path from pg
--
-- Restores the api_work_refresh() body from
-- function-api-work-20260915-incremental-refresh verbatim.

BEGIN;

    CREATE OR REPLACE FUNCTION structs.api_work_refresh(
        p_source_height BIGINT,
        p_source_time   TIMESTAMPTZ DEFAULT NOW()
    )
    RETURNS TABLE (inserted BIGINT, updated BIGINT, deleted BIGINT)
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    DECLARE
        v_inserted BIGINT := 0;
        v_updated  BIGINT := 0;
        v_deleted  BIGINT := 0;
        v_dirty    INT;
        v_keys     VARCHAR[];
    BEGIN
        IF p_source_height IS NULL OR p_source_height < 0 THEN
            RAISE EXCEPTION 'api_work_refresh: source_height must be a non-negative block height, got %',
                p_source_height;
        END IF;

        PERFORM pg_advisory_xact_lock(hashtext('structs.api_work_refresh'));

        -- Drain the queue into this transaction.
        DROP TABLE IF EXISTS pg_temp.api_work_dirty_tmp;
        CREATE TEMP TABLE api_work_dirty_tmp (kind TEXT, id VARCHAR) ON COMMIT DROP;
        WITH drained AS (
            DELETE FROM structs.api_work_dirty RETURNING kind, id
        )
        INSERT INTO api_work_dirty_tmp (kind, id)
        SELECT kind, id FROM drained;

        GET DIAGNOSTICS v_dirty = ROW_COUNT;

        IF v_dirty = 0 THEN
            INSERT INTO structs.api_refresh_state (model, source_height, source_time, refreshed_at)
            VALUES ('work', p_source_height, p_source_time, NOW())
            ON CONFLICT (model) DO UPDATE
               SET source_height = EXCLUDED.source_height,
                   source_time   = EXCLUDED.source_time,
                   refreshed_at  = EXCLUDED.refreshed_at;
            RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT;
            RETURN;
        END IF;

        IF v_dirty > 2000 THEN
            RETURN QUERY SELECT * FROM structs.api_work_refresh_full(p_source_height, p_source_time, FALSE);
            RETURN;
        END IF;

        -- Expand to the work-row targets that can be affected:
        --   target_id is struct.id for BUILD/MINE/REFINE and planet.id for RAID.
        SELECT array_agg(DISTINCT t) INTO v_keys
          FROM (
                SELECT d.id AS t FROM api_work_dirty_tmp d WHERE d.kind = 'struct'
                UNION ALL
                SELECT d.id FROM api_work_dirty_tmp d WHERE d.kind = 'planet'
                UNION ALL
                SELECT s.id FROM api_work_dirty_tmp d
                  JOIN structs.struct s ON s.location_id = d.id AND s.location_type = 'planet'
                 WHERE d.kind = 'planet'
                UNION ALL
                SELECT s.id FROM api_work_dirty_tmp d
                  JOIN structs.struct s ON s.owner = d.id
                 WHERE d.kind = 'player'
                UNION ALL
                SELECT p.id FROM api_work_dirty_tmp d
                  JOIN structs.planet p ON p.location_list_start = d.id
                 WHERE d.kind = 'fleet'
               ) k;

        IF v_keys IS NULL THEN
            -- dirty keys that influence nothing (e.g. a fleet raiding no planet)
            INSERT INTO structs.api_refresh_state (model, source_height, source_time, refreshed_at)
            VALUES ('work', p_source_height, p_source_time, NOW())
            ON CONFLICT (model) DO UPDATE
               SET source_height = EXCLUDED.source_height,
                   source_time   = EXCLUDED.source_time,
                   refreshed_at  = EXCLUDED.refreshed_at;
            RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT;
            RETURN;
        END IF;

        -- Recompute only those targets through the specification.
        DROP TABLE IF EXISTS pg_temp.api_work_live_tmp;
        CREATE TEMP TABLE api_work_live_tmp ON COMMIT DROP AS
            SELECT w.object_id, w.player_id, w.target_id, w.category, w.block_start,
                   w.difficulty_target, w.location_type, w.location_id, w.planet_id
              FROM view.work_live w
             WHERE w.target_id = ANY (v_keys);

        WITH del AS (
            DELETE FROM structs.api_work aw
             WHERE aw.target_id = ANY (v_keys)
               AND NOT EXISTS (
                       SELECT 1 FROM api_work_live_tmp l
                        WHERE l.category  = aw.category
                          AND l.object_id = aw.object_id
                          AND l.target_id = aw.target_id
                   )
            RETURNING 1
        )
        SELECT count(*) INTO v_deleted FROM del;

        WITH ups AS (
            INSERT INTO structs.api_work AS aw
                (object_id, player_id, target_id, category, block_start,
                 difficulty_target, location_type, location_id, planet_id,
                 source_height, updated_at)
            SELECT l.object_id, l.player_id, l.target_id, l.category, l.block_start,
                   l.difficulty_target, l.location_type, l.location_id, l.planet_id,
                   p_source_height, NOW()
              FROM api_work_live_tmp l
            ON CONFLICT (category, object_id, target_id) DO UPDATE
               SET player_id         = EXCLUDED.player_id,
                   block_start       = EXCLUDED.block_start,
                   difficulty_target = EXCLUDED.difficulty_target,
                   location_type     = EXCLUDED.location_type,
                   location_id       = EXCLUDED.location_id,
                   planet_id         = EXCLUDED.planet_id,
                   source_height     = EXCLUDED.source_height,
                   updated_at        = EXCLUDED.updated_at
             WHERE (aw.player_id, aw.block_start, aw.difficulty_target,
                    aw.location_type, aw.location_id, aw.planet_id)
                   IS DISTINCT FROM
                   (EXCLUDED.player_id, EXCLUDED.block_start, EXCLUDED.difficulty_target,
                    EXCLUDED.location_type, EXCLUDED.location_id, EXCLUDED.planet_id)
            RETURNING (xmax = 0) AS is_insert
        )
        SELECT count(*) FILTER (WHERE is_insert),
               count(*) FILTER (WHERE NOT is_insert)
          INTO v_inserted, v_updated
          FROM ups;

        INSERT INTO structs.api_refresh_state (model, source_height, source_time, refreshed_at)
        VALUES ('work', p_source_height, p_source_time, NOW())
        ON CONFLICT (model) DO UPDATE
           SET source_height = EXCLUDED.source_height,
               source_time   = EXCLUDED.source_time,
               refreshed_at  = EXCLUDED.refreshed_at;

        RETURN QUERY SELECT v_inserted, v_updated, v_deleted;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.api_work_refresh(BIGINT, TIMESTAMPTZ) IS
        'Incremental per-block refresh of structs.api_work: drains api_work_dirty, recomputes only the affected targets through view.work_live, records model ''work'' in api_refresh_state. Empty queue costs ~1 ms. Falls back to api_work_refresh_full() above 2,000 keys. Returns (inserted, updated, deleted).';

COMMIT;
