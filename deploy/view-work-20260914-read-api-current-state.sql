-- Deploy structs-pg:view-work-20260914-read-api-current-state to pg
--
-- Re-point view.work at structs.api_work. The webapp keeps its query; the
-- per-read recompute of the work list stops here.
--
-- Guarded: the deploy aborts unless sync-state has refreshed api_work within
-- the last five minutes (api_refresh_state.work). This is the same gate the
-- rollout order in docs/sync-state-ledger-identity-handoff.md §6 describes,
-- enforced in the migration so an early merge cannot serve a stale table.
-- The one-time refresh below then makes the table current as of this
-- transaction, so there is no gap between the last sync-state refresh and the
-- cutover.

BEGIN;

    DO $$
    DECLARE
        v_refreshed_at TIMESTAMPTZ;
    BEGIN
        SELECT refreshed_at INTO v_refreshed_at
          FROM structs.api_refresh_state
         WHERE model = 'work';

        IF v_refreshed_at IS NULL THEN
            RAISE EXCEPTION 'view.work re-point refused: structs.api_work has never been refreshed; sync-state must call structs.api_work_refresh() every block first';
        END IF;

        IF v_refreshed_at < NOW() - INTERVAL '5 minutes' THEN
            RAISE EXCEPTION 'view.work re-point refused: structs.api_work last refreshed at % (% ago); sync-state is not calling structs.api_work_refresh() every block',
                v_refreshed_at, NOW() - v_refreshed_at;
        END IF;
    END
    $$;

    -- Bring the table to the state visible in this transaction.
    SELECT structs.api_work_refresh(
        (SELECT source_height FROM structs.api_refresh_state WHERE model = 'work'),
        NOW()
    );

    CREATE OR REPLACE VIEW view.work AS
        SELECT object_id, player_id, target_id, category, block_start,
               difficulty_target, location_type, location_id, planet_id
          FROM structs.api_work;

    COMMENT ON VIEW view.work IS
        'Work list (BUILD/MINE/REFINE/RAID) read from structs.api_work, which sync-state refreshes every block via structs.api_work_refresh(). Specification: view.work_live.';

COMMIT;
