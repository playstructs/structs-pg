-- Revert structs-pg:role-structs-indexer-20260522-drop-cache-tx-results-grant from pg
--
-- Restores the original cache.tx_results grant from role-structs-indexer.sql:12.
-- EXISTS-guarded so a partial revert against a post-cutover DB is a no-op.

BEGIN;

    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'structs_indexer')
           AND EXISTS (SELECT 1 FROM information_schema.tables
                        WHERE table_schema = 'cache' AND table_name = 'tx_results') THEN
            GRANT INSERT, SELECT ON cache.tx_results TO structs_indexer;
        END IF;
    END $$;

COMMIT;
