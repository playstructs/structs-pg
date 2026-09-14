-- Deploy structs-pg:cron-job-run-details-20260914-retention to pg
--
-- pg_cron appends one cron.job_run_details row per run and never prunes it.
-- Three jobs on a 59 second schedule produce ~4,400 rows a day; the table had
-- 345k rows (55 MB) going back to May. Keep a week of history.

BEGIN;

    CREATE OR REPLACE PROCEDURE structs.CLEAN_CRON_HISTORY()
    AS
    $BODY$
    BEGIN
        DELETE FROM cron.job_run_details
            WHERE end_time < NOW() - '7 days'::interval;
    END
    $BODY$ LANGUAGE plpgsql SECURITY DEFINER;

    SELECT cron.schedule('cron_history_cleaner', '41 4 * * *', 'CALL structs.CLEAN_CRON_HISTORY();');

COMMIT;
