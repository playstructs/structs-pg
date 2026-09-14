-- Deploy structs-pg:table-api-work-20260914-reconciliation to pg
--
-- Nightly check that structs.api_work matches view.work_live. Because the
-- refresh logic lives in the database (api_work_refresh), drift here means
-- sync-state stopped calling the refresh, called it before its block writes,
-- or a refresh transaction rolled back. It is not expected to fire.
--
-- structs.api_work_reconcile(p_log) returns every key that is missing from
-- api_work, extra in api_work, or stale (present in both with different
-- values), with both rows as jsonb, and logs them to api_work_drift when
-- p_log. Repair is simply the next api_work_refresh() call.

BEGIN;

    CREATE TABLE structs.api_work_drift (
        checked_at    TIMESTAMPTZ NOT NULL,
        category      TEXT NOT NULL,
        object_id     CHARACTER VARYING NOT NULL,
        target_id     CHARACTER VARYING NOT NULL,
        state         TEXT NOT NULL CHECK (state IN ('missing', 'extra', 'stale')),
        api_row       JSONB,
        live_row      JSONB,
        source_height BIGINT,
        PRIMARY KEY (checked_at, category, object_id, target_id)
    );

    COMMENT ON TABLE structs.api_work_drift IS
        'Differences between structs.api_work and view.work_live, one batch per checked_at. state: missing (only in live), extra (only in api_work), stale (values differ). Written by structs.api_work_reconcile().';

    CREATE OR REPLACE FUNCTION structs.api_work_reconcile(p_log BOOLEAN DEFAULT TRUE)
    RETURNS TABLE (
        category  TEXT,
        object_id CHARACTER VARYING,
        target_id CHARACTER VARYING,
        state     TEXT,
        api_row   JSONB,
        live_row  JSONB
    )
    LANGUAGE plpgsql
    SET max_parallel_workers_per_gather = 0
    AS
    $BODY$
    #variable_conflict use_column
    DECLARE
        v_checked_at    TIMESTAMPTZ := clock_timestamp();
        v_source_height BIGINT;
    BEGIN
        SELECT rs.source_height INTO v_source_height
          FROM structs.api_refresh_state rs
         WHERE rs.model = 'work';

        DROP TABLE IF EXISTS pg_temp.api_work_reconcile_tmp;

        CREATE TEMP TABLE api_work_reconcile_tmp ON COMMIT DROP AS
        SELECT COALESCE(l.category,  a.category)  AS category,
               COALESCE(l.object_id, a.object_id) AS object_id,
               COALESCE(l.target_id, a.target_id) AS target_id,
               CASE
                   WHEN a.category IS NULL THEN 'missing'
                   WHEN l.category IS NULL THEN 'extra'
                   ELSE 'stale'
               END AS state,
               CASE WHEN a.category IS NULL THEN NULL ELSE jsonb_build_object(
                   'player_id', a.player_id, 'block_start', a.block_start,
                   'difficulty_target', a.difficulty_target, 'location_type', a.location_type,
                   'location_id', a.location_id, 'planet_id', a.planet_id,
                   'source_height', a.source_height) END AS api_row,
               CASE WHEN l.category IS NULL THEN NULL ELSE jsonb_build_object(
                   'player_id', l.player_id, 'block_start', l.block_start,
                   'difficulty_target', l.difficulty_target, 'location_type', l.location_type,
                   'location_id', l.location_id, 'planet_id', l.planet_id) END AS live_row
          FROM view.work_live l
          FULL OUTER JOIN structs.api_work a
            ON a.category  = l.category
           AND a.object_id = l.object_id
           AND a.target_id = l.target_id
         WHERE a.category IS NULL
            OR l.category IS NULL
            OR (a.player_id, a.block_start, a.difficulty_target,
                a.location_type, a.location_id, a.planet_id)
               IS DISTINCT FROM
               (l.player_id, l.block_start, l.difficulty_target,
                l.location_type, l.location_id, l.planet_id);

        IF p_log THEN
            INSERT INTO structs.api_work_drift
                (checked_at, category, object_id, target_id, state, api_row, live_row, source_height)
            SELECT v_checked_at, t.category, t.object_id, t.target_id,
                   t.state, t.api_row, t.live_row, v_source_height
              FROM api_work_reconcile_tmp t;

            DELETE FROM structs.api_work_drift d
             WHERE d.checked_at < v_checked_at - INTERVAL '90 days';
        END IF;

        RETURN QUERY
            SELECT t.category, t.object_id, t.target_id, t.state, t.api_row, t.live_row
              FROM api_work_reconcile_tmp t
             ORDER BY t.category, t.object_id, t.target_id;
    END
    $BODY$;

    COMMENT ON FUNCTION structs.api_work_reconcile(BOOLEAN) IS
        'Compare structs.api_work with view.work_live. Returns missing/extra/stale keys; logs them to api_work_drift when p_log. Read-only with respect to api_work; the next api_work_refresh() repairs any drift.';

    GRANT EXECUTE
        ON FUNCTION structs.api_work_reconcile(BOOLEAN)
        TO structs_indexer;

    GRANT SELECT, UPDATE, DELETE
        ON structs.api_work_drift
        TO structs_indexer;

    SELECT cron.schedule(
        'api_work_reconciler',
        '23 3 * * *',
        'SELECT count(*) FROM structs.api_work_reconcile(TRUE);'
    );

COMMIT;
