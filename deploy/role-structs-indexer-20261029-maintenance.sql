-- Deploy structs-pg:role-structs-indexer-20261029-maintenance to pg
BEGIN;
-- The existing maintenance functions execute as their caller. Grant only the
-- source reads they need; existing migrations grant their projection writes.
GRANT USAGE ON SCHEMA view TO structs_indexer;
GRANT SELECT ON sync_state.sync_cursor, structs.current_block,
    structs.ledger, structs.struct, structs.planet, view.work_live TO structs_indexer;
COMMIT;
