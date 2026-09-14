-- Verify structs-pg:table-api-inventory-20260914-reconciliation on pg

BEGIN;

    SELECT checked_at, owner_type, owner_id, denom,
           api_balance, ledger_balance, source_height
      FROM structs.api_inventory_drift WHERE FALSE;

    DO $$
    BEGIN
        IF to_regprocedure('structs.api_inventory_reconcile(boolean)') IS NULL THEN
            RAISE EXCEPTION 'expected function structs.api_inventory_reconcile(boolean)';
        END IF;

        IF to_regclass('structs.api_inventory_drift_owner_idx') IS NULL THEN
            RAISE EXCEPTION 'expected index structs.api_inventory_drift_owner_idx';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM cron.job WHERE jobname = 'api_inventory_reconciler'
        ) THEN
            RAISE EXCEPTION 'api_inventory_reconciler cron job is not scheduled';
        END IF;
    END
    $$;

    -- The function must be callable without logging and must not touch
    -- api_inventory. Row content depends on live data, so only shape is
    -- checked here.
    SELECT owner_type, owner_id, denom, api_balance, ledger_balance
      FROM structs.api_inventory_reconcile(FALSE) WHERE FALSE;

ROLLBACK;
