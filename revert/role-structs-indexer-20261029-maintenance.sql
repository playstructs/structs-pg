-- Revert structs-pg:role-structs-indexer-20261029-maintenance from pg
BEGIN;
REVOKE SELECT ON sync_state.sync_cursor, structs.current_block,
    structs.struct, structs.planet, view.work_live FROM structs_indexer;
REVOKE USAGE ON SCHEMA view FROM structs_indexer;
-- Keep ledger SELECT: the paired ledger writer contract also grants it, and
-- reverting this maintenance addition must not remove another change's grant.
COMMIT;
