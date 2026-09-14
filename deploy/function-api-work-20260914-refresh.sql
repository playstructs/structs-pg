-- Deploy structs-pg:function-api-work-20260914-refresh to pg
--
-- structs.api_work_refresh(source_height, source_time) brings structs.api_work
-- in line with view.work_live in one call. sync-state calls it at the end of
-- every block transaction, after all authoritative writes for the block, and
-- once for the initial backfill. The database owns the work-list logic (the
-- view); sync-state owns when it runs. No dirty-key tracking is needed:
--
--   1. compute view.work_live once into a temp set;
--   2. DELETE api_work rows whose key is no longer in the set;
--   3. INSERT ... ON CONFLICT DO UPDATE the set, but only touch rows whose
--      visible values actually changed (IS DISTINCT FROM guard), so unchanged
--      rows are not rewritten and there is no per-block churn;
--   4. record model 'work' in structs.api_refresh_state.
--
-- Returns the number of rows inserted, updated and deleted so callers can log
-- it. Idempotent: calling it twice for the same block does nothing the second
-- time. Single writer assumed (sync-state); the nightly reconciler only reads.
--
-- source_height on a row is the height at which that row last changed;
-- api_refresh_state.source_height for 'work' is the height last refreshed to.
--
-- Parallel workers are disabled because the container's /dev/shm is 64 MB
-- (see docs/sync-state-ledger-identity-handoff.md §7).

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
    BEGIN
        IF p_source_height IS NULL OR p_source_height < 0 THEN
            RAISE EXCEPTION 'api_work_refresh: source_height must be a non-negative block height, got %',
                p_source_height;
        END IF;

        DROP TABLE IF EXISTS pg_temp.api_work_live_tmp;

        CREATE TEMP TABLE api_work_live_tmp ON COMMIT DROP AS
            SELECT w.object_id, w.player_id, w.target_id, w.category, w.block_start,
                   w.difficulty_target, w.location_type, w.location_id, w.planet_id
              FROM view.work_live w;

        CREATE INDEX ON api_work_live_tmp (category, object_id, target_id);

        WITH del AS (
            DELETE FROM structs.api_work aw
             WHERE NOT EXISTS (
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
        'Diff structs.api_work against view.work_live: delete vanished rows, upsert changed rows, record model ''work'' in api_refresh_state. Call once at the end of each block transaction. Returns (inserted, updated, deleted).';

    GRANT EXECUTE
        ON FUNCTION structs.api_work_refresh(BIGINT, TIMESTAMPTZ)
        TO structs_indexer;

COMMIT;
