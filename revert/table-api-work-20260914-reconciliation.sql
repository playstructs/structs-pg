-- Revert structs-pg:table-api-work-20260914-reconciliation from pg

BEGIN;

    SELECT cron.unschedule('api_work_reconciler');

    DROP FUNCTION IF EXISTS structs.api_work_reconcile(BOOLEAN);

    DROP TABLE IF EXISTS structs.api_work_drift;

COMMIT;
