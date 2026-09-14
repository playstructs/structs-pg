-- Verify structs-pg:table-api-work-20260914-reconciliation on pg
--
-- Refresh then reconcile inside a rolled-back transaction: after a refresh
-- the reconciler must report nothing.

BEGIN;

    SELECT checked_at, category, object_id, target_id, state, api_row, live_row, source_height
      FROM structs.api_work_drift WHERE FALSE;

    DO $$
    DECLARE
        drift_count bigint;
    BEGIN
        IF to_regprocedure('structs.api_work_reconcile(boolean)') IS NULL THEN
            RAISE EXCEPTION 'expected function structs.api_work_reconcile(boolean)';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM cron.job WHERE jobname = 'api_work_reconciler'
        ) THEN
            RAISE EXCEPTION 'api_work_reconciler cron job is not scheduled';
        END IF;

        PERFORM structs.api_work_refresh(0, now());
        SELECT count(*) INTO drift_count FROM structs.api_work_reconcile(FALSE);
        IF drift_count <> 0 THEN
            RAISE EXCEPTION 'api_work_reconcile reports % rows immediately after api_work_refresh',
                drift_count;
        END IF;
    END
    $$;

ROLLBACK;
