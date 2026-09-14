-- Revert structs-pg:role-structs-indexer-20260914-api-work-and-drift from pg

BEGIN;

    REVOKE EXECUTE
        ON FUNCTION structs.api_inventory_reconcile(BOOLEAN)
        FROM structs_indexer;

    REVOKE SELECT, UPDATE, DELETE
        ON structs.api_inventory_drift
        FROM structs_indexer;

    REVOKE SELECT, INSERT, UPDATE, DELETE
        ON structs.api_work
        FROM structs_indexer;

COMMIT;
