-- Revert structs-pg:function-api-work-20260915-incremental-refresh from pg
--
-- Restores the full-pass api_work_refresh() from
-- function-api-work-20260914-refresh, removes the queue, triggers, the full
-- variant and the hourly cron job.

BEGIN;

    SELECT cron.unschedule('api-work-refresh-full-hourly');

    DROP TRIGGER IF EXISTS api_work_dirty_ins ON structs.struct;
    DROP TRIGGER IF EXISTS api_work_dirty_upd ON structs.struct;
    DROP TRIGGER IF EXISTS api_work_dirty_del ON structs.struct;
    DROP TRIGGER IF EXISTS api_work_dirty_ins ON structs.struct_attribute;
    DROP TRIGGER IF EXISTS api_work_dirty_upd ON structs.struct_attribute;
    DROP TRIGGER IF EXISTS api_work_dirty_del ON structs.struct_attribute;
    DROP TRIGGER IF EXISTS api_work_dirty_ins ON structs.planet_attribute;
    DROP TRIGGER IF EXISTS api_work_dirty_upd ON structs.planet_attribute;
    DROP TRIGGER IF EXISTS api_work_dirty_del ON structs.planet_attribute;
    DROP TRIGGER IF EXISTS api_work_dirty_ins ON structs.grid;
    DROP TRIGGER IF EXISTS api_work_dirty_upd ON structs.grid;
    DROP TRIGGER IF EXISTS api_work_dirty_del ON structs.grid;
    DROP TRIGGER IF EXISTS api_work_dirty_ins ON structs.planet;
    DROP TRIGGER IF EXISTS api_work_dirty_upd ON structs.planet;
    DROP TRIGGER IF EXISTS api_work_dirty_del ON structs.planet;
    DROP TRIGGER IF EXISTS api_work_dirty_ins ON structs.fleet;
    DROP TRIGGER IF EXISTS api_work_dirty_upd ON structs.fleet;
    DROP TRIGGER IF EXISTS api_work_dirty_del ON structs.fleet;

    DROP FUNCTION IF EXISTS structs.api_work_mark_dirty();
    DROP FUNCTION IF EXISTS structs.api_work_refresh_full(BIGINT, TIMESTAMPTZ, BOOLEAN);
    DROP TABLE IF EXISTS structs.api_work_dirty;
    DROP INDEX IF EXISTS structs.struct_location_id_idx;

    -- original body, verbatim from function-api-work-20260914-refresh
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
