-- Revert structs-pg:table-api-inventory-20260914-reconciliation from pg

BEGIN;

    SELECT cron.unschedule('api_inventory_reconciler');

    DROP FUNCTION IF EXISTS structs.api_inventory_reconcile(BOOLEAN);

    DROP TABLE IF EXISTS structs.api_inventory_drift;

COMMIT;
