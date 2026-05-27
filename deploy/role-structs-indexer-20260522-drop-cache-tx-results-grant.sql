-- Deploy structs-pg:role-structs-indexer-20260522-drop-cache-tx-results-grant to pg
--
-- Removes the cache.tx_results INSERT grant from structs_indexer. The
-- structs_indexer role was used by update-cache (the Tendermint psql
-- sink), which is being decommissioned in favor of the sync-state Go
-- binary. After retire-cache-20260522, cache.tx_results becomes a
-- SELECT-only compatibility view over sync_state.raw_tx_results, so the
-- INSERT grant becomes meaningless even if the GRANT statement still
-- succeeds.
--
-- The other three cache.* indexer grants (cache.events, cache.blocks,
-- cache.attributes) also become moot post-cutover but are not removed
-- here — the GRANT statements remain syntactically valid against the
-- views, and update-cache decommissioning is the canonical fix. Revisit
-- as part of the future cache-* squash milestone.

BEGIN;

    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'structs_indexer')
           AND EXISTS (SELECT 1 FROM information_schema.tables
                        WHERE table_schema = 'cache' AND table_name = 'tx_results') THEN
            REVOKE INSERT, SELECT ON cache.tx_results FROM structs_indexer;
        END IF;
    END $$;

COMMIT;
