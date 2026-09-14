-- Verify structs-pg:cron-job-run-details-20260914-retention on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regprocedure('structs.clean_cron_history()') IS NULL THEN
            RAISE EXCEPTION 'expected procedure structs.CLEAN_CRON_HISTORY()';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM cron.job WHERE jobname = 'cron_history_cleaner'
        ) THEN
            RAISE EXCEPTION 'cron_history_cleaner cron job is not scheduled';
        END IF;
    END
    $$;

ROLLBACK;
