-- Revert structs-pg:cron-job-run-details-20260914-retention from pg

BEGIN;

    SELECT cron.unschedule('cron_history_cleaner');

    DROP PROCEDURE IF EXISTS structs.CLEAN_CRON_HISTORY();

COMMIT;
