-- Deploy structs-pg:view-work-20260914-read-api-current-state to pg
--
-- Re-point view.work at structs.api_work. Readers keep their query; the
-- per-read recompute of the work list (view.work_live, ~90 ms) stops here.
--
-- Guard. Until 2026-09-15 sync-state populated api_work with its own
-- statement, INSERT INTO structs.api_work ... SELECT ... FROM view.work w
-- WHERE <dirty ids>, and wrote api_refresh_state itself. Had this view swap
-- shipped while that statement was live, the INSERT would have selected
-- from the table it was inserting into and api_work would have frozen with
-- no error anywhere. A freshness check on api_refresh_state cannot tell the
-- two writers apart, so the guard observes the writers directly over a
-- 20-second window:
--
--   1. structs.api_work_refresh() must be called at least once
--      (pg_stat_user_functions; requires track_functions = pl, which the
--      image sets -- if it is off the count stays at zero and the deploy
--      fails closed).
--   2. The retired INSERT ... FROM view.work must not be called at all
--      (pg_stat_statements, when installed).
--   3. api_refresh_state.work must be fresh, as before.
--
-- A database that has never recorded a work refresh has nothing for that
-- window to observe. Fresh installs hit this change before sync-state has
-- run, so api_refresh_state.work is absent, api_work and view.work_live are
-- empty, and neither writer has been called. Refusing there blocks every
-- later change in the plan. That case deploys with a NOTICE. Still refused:
-- work rows exist with no refresh row, either writer has already been
-- called, or a recorded refresh is older than 5 minutes.
--
-- No refresh is run here: sync-state is the single caller of
-- api_work_refresh() (every block, ~5 s) and the function is not designed
-- for concurrent callers. The view swap is atomic and api_work is already
-- at parity with view.work_live, so there is no gap to close.

BEGIN;

    DO $$
    DECLARE
        v_refreshed_at   TIMESTAMPTZ;
        v_fn_before      BIGINT;
        v_fn_after       BIGINT;
        v_dirty_before   BIGINT := 0;
        v_dirty_after    BIGINT := 0;
        v_has_pss        BOOLEAN;
    BEGIN
        SELECT refreshed_at INTO v_refreshed_at
          FROM structs.api_refresh_state WHERE model = 'work';

        v_has_pss := EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements');

        IF v_refreshed_at IS NULL THEN
            IF EXISTS (SELECT 1 FROM structs.api_work)
               OR EXISTS (SELECT 1 FROM view.work_live) THEN
                RAISE EXCEPTION 'view.work re-point refused: api_refresh_state.work is absent but work rows exist; api_work is not being refreshed';
            END IF;

            SELECT COALESCE(SUM(calls), 0) INTO v_fn_before
              FROM pg_stat_user_functions
             WHERE schemaname = 'structs' AND funcname = 'api_work_refresh';
            IF v_fn_before > 0 THEN
                RAISE EXCEPTION 'view.work re-point refused: api_refresh_state.work is absent but structs.api_work_refresh() has been called % time(s) since this server started',
                    v_fn_before;
            END IF;

            IF v_has_pss THEN
                SELECT COALESCE(SUM(calls), 0) INTO v_dirty_before
                  FROM pg_stat_statements
                 WHERE query LIKE 'INSERT INTO structs.api_work%FROM view.work w%';
                IF v_dirty_before > 0 THEN
                    RAISE EXCEPTION 'view.work re-point refused: api_refresh_state.work is absent but the retired INSERT INTO structs.api_work ... FROM view.work has been called % time(s) since this server started',
                        v_dirty_before;
                END IF;
            END IF;

            RAISE NOTICE 'view.work re-point: api_refresh_state.work is absent, api_work and view.work_live are empty, and no writer has been recorded; nothing to protect on a fresh database';
            RETURN;
        END IF;

        IF v_refreshed_at < NOW() - INTERVAL '5 minutes' THEN
            RAISE EXCEPTION 'view.work re-point refused: api_refresh_state.work is % (last %); api_work is not being refreshed',
                (NOW() - v_refreshed_at)::text, v_refreshed_at;
        END IF;

        SELECT COALESCE(SUM(calls), 0) INTO v_fn_before
          FROM pg_stat_user_functions
         WHERE schemaname = 'structs' AND funcname = 'api_work_refresh';
        IF v_has_pss THEN
            SELECT COALESCE(SUM(calls), 0) INTO v_dirty_before
              FROM pg_stat_statements
             WHERE query LIKE 'INSERT INTO structs.api_work%FROM view.work w%';
        END IF;

        PERFORM pg_sleep(20);
        -- Cumulative statistics are snapshotted per transaction
        -- (stats_fetch_consistency = cache); drop the snapshot so the second
        -- read sees the calls made during the sleep.
        PERFORM pg_stat_clear_snapshot();

        SELECT COALESCE(SUM(calls), 0) INTO v_fn_after
          FROM pg_stat_user_functions
         WHERE schemaname = 'structs' AND funcname = 'api_work_refresh';
        IF v_has_pss THEN
            SELECT COALESCE(SUM(calls), 0) INTO v_dirty_after
              FROM pg_stat_statements
             WHERE query LIKE 'INSERT INTO structs.api_work%FROM view.work w%';
        END IF;

        IF v_fn_after <= v_fn_before THEN
            RAISE EXCEPTION 'view.work re-point refused: structs.api_work_refresh() was not called in the last 20 s (calls % -> %); sync-state is not on the refresh path, or track_functions is off',
                v_fn_before, v_fn_after;
        END IF;

        IF v_dirty_after > v_dirty_before THEN
            RAISE EXCEPTION 'view.work re-point refused: the retired sync-state statement INSERT INTO structs.api_work ... FROM view.work ran % time(s) in the last 20 s; re-pointing now would make api_work read from itself',
                v_dirty_after - v_dirty_before;
        END IF;

        RAISE NOTICE 'view.work re-point: api_work_refresh() calls % -> %, dirty INSERT calls % -> %, last refresh % ago',
            v_fn_before, v_fn_after, v_dirty_before, v_dirty_after, NOW() - v_refreshed_at;
    END
    $$;

    CREATE OR REPLACE VIEW view.work AS
        SELECT object_id, player_id, target_id, category, block_start,
               difficulty_target, location_type, location_id, planet_id
          FROM structs.api_work;

    COMMENT ON VIEW view.work IS
        'Work list (BUILD/MINE/REFINE/RAID) read from structs.api_work, which sync-state refreshes every block via structs.api_work_refresh(). Specification: view.work_live.';

COMMIT;
