-- Revert structs-pg:table-defusion-20261029-receipts from pg
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE structs.defusion IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.defusion WHERE chain_id IS NOT NULL)
       OR EXISTS (SELECT 1 FROM sync_state.native_staking_snapshot WHERE receipts_pending) THEN
        RAISE EXCEPTION 'receipt identity, reconciliation, or pending work exists; preserve replay safety or restore a verified checkpoint';
    END IF;
END $$;
DROP VIEW structs.defusion_current;
DROP INDEX structs.defusion_source_event_uidx;
DROP INDEX structs.defusion_active_delegator_idx;
DROP INDEX structs.defusion_active_validator_idx;
DROP INDEX sync_state.native_staking_receipts_pending_idx;
ALTER TABLE sync_state.native_staking_snapshot DROP COLUMN receipts_pending;
ALTER TABLE structs.defusion DROP CONSTRAINT defusion_source_identity, DROP CONSTRAINT defusion_reconciliation_boundary,
    DROP COLUMN chain_id, DROP COLUMN block_height, DROP COLUMN tx_index, DROP COLUMN event_index,
    DROP COLUMN source_validator_address, DROP COLUMN legacy_observed_height, DROP COLUMN reconciled_height, DROP COLUMN retired_height;
COMMENT ON TABLE structs.defusion IS NULL;
COMMENT ON COLUMN structs.defusion.completed_at IS NULL;
CREATE OR REPLACE PROCEDURE structs.CLEAN_DEFUSION()
AS $BODY$
BEGIN
    DELETE FROM structs.defusion WHERE completed_at < NOW();
END
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;
SELECT cron.schedule('defusion_cleaner','59 seconds','CALL structs.CLEAN_DEFUSION();');
COMMIT;
