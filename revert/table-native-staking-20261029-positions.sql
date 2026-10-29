-- Revert structs-pg:table-native-staking-20261029-positions from pg
BEGIN;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM sync_state.native_staking_snapshot WHERE positions_complete)
        OR EXISTS (SELECT 1 FROM sync_state.native_staking_position) THEN
        RAISE EXCEPTION 'native position evidence is active; restore the coordinated checkpoint to downgrade';
    END IF;
END $$;
DROP VIEW sync_state.native_staking_position_state;
DROP TABLE sync_state.native_staking_position;
DROP INDEX sync_state.native_staking_positions_pending_idx;
ALTER TABLE sync_state.native_staking_snapshot DROP COLUMN positions_complete;
COMMIT;
