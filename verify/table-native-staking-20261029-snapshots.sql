-- Verify structs-pg:table-native-staking-20261029-snapshots on pg
BEGIN;
SELECT chain_id,address,required_height,source_height,bonded,unbonding,fetched_at,retry_after,pending
FROM sync_state.native_staking_snapshot WHERE FALSE;
SELECT chain_id,validator,address FROM sync_state.native_staking_exposure WHERE FALSE;
SELECT chain_id,validator,height FROM sync_state.native_staking_invalidation WHERE FALSE;
SELECT chain_id,address,complete,bonded,unbonding FROM sync_state.native_staking_claim WHERE FALSE;
DO $$
DECLARE rel TEXT; privilege TEXT;
BEGIN
    FOREACH rel IN ARRAY ARRAY['native_staking_snapshot','native_staking_exposure','native_staking_invalidation'] LOOP
        FOREACH privilege IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE'] LOOP
            IF NOT has_table_privilege('structs_indexer','sync_state.' || rel,privilege) THEN
                RAISE EXCEPTION 'missing % on %',privilege,rel;
            END IF;
        END LOOP;
    END LOOP;
    IF NOT has_table_privilege('structs_indexer','sync_state.native_staking_claim','SELECT') THEN
        RAISE EXCEPTION 'missing native claim read access';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_index WHERE indexrelid='sync_state.native_staking_snapshot_pending_idx'::regclass
        AND indisvalid AND indpred IS NOT NULL) THEN
        RAISE EXCEPTION 'missing bounded pending-work index';
    END IF;
END $$;
ROLLBACK;
