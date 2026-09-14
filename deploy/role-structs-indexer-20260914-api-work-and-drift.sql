-- Deploy structs-pg:role-structs-indexer-20260914-api-work-and-drift to pg
--
-- sync-state maintains structs.api_work and consumes/repairs
-- structs.api_inventory_drift. It may also run the reconciler on demand
-- (for example after a replay) instead of waiting for the nightly job.

BEGIN;

    GRANT SELECT, INSERT, UPDATE, DELETE
        ON structs.api_work
        TO structs_indexer;

    GRANT SELECT, UPDATE, DELETE
        ON structs.api_inventory_drift
        TO structs_indexer;

    GRANT EXECUTE
        ON FUNCTION structs.api_inventory_reconcile(BOOLEAN)
        TO structs_indexer;

COMMIT;
