-- Revert structs-pg:table-native-staking-20261029-snapshots from pg
BEGIN;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM sync_state.native_staking_snapshot)
       OR EXISTS (SELECT 1 FROM sync_state.native_staking_invalidation) THEN
        RAISE EXCEPTION 'native staking evidence or invalidations exist; retain their completeness boundary or restore a verified checkpoint';
    END IF;
END $$;
DROP VIEW sync_state.native_staking_claim;
DROP TABLE sync_state.native_staking_invalidation;
DROP TABLE sync_state.native_staking_exposure;
DROP TABLE sync_state.native_staking_snapshot;
COMMIT;
