-- Deploy structs-pg:table-defusion-20261029-receipts to pg
BEGIN;
SET LOCAL lock_timeout = '5s';
ALTER TABLE structs.defusion
    ADD COLUMN chain_id TEXT,
    ADD COLUMN block_height BIGINT,
    ADD COLUMN tx_index INTEGER,
    ADD COLUMN event_index INTEGER,
    ADD COLUMN source_validator_address VARCHAR,
    ADD COLUMN legacy_observed_height BIGINT,
    ADD COLUMN reconciled_height BIGINT,
    ADD COLUMN retired_height BIGINT,
    ADD CONSTRAINT defusion_source_identity CHECK (
        (chain_id IS NULL AND block_height IS NULL AND tx_index IS NULL AND event_index IS NULL AND legacy_observed_height IS NULL)
        OR (chain_id IS NOT NULL AND chain_id <> '' AND (
            (block_height IS NOT NULL AND block_height > 0 AND tx_index IS NOT NULL AND tx_index >= -1
                AND event_index IS NOT NULL AND event_index >= 0 AND legacy_observed_height IS NULL
                AND validator_address IS NOT NULL AND delegator_address IS NOT NULL
                AND defusion_type IS NOT NULL AND defusion_type IN ('u','r')
                AND amount_p IS NOT NULL AND amount_p >= 0 AND amount_p < 'Infinity'::numeric AND amount_p = trunc(amount_p)
                AND denom IS NOT NULL AND denom <> '' AND completed_at IS NOT NULL AND created_at IS NOT NULL
                AND (defusion_type <> 'r' OR source_validator_address IS NOT NULL))
            OR (block_height IS NULL AND tx_index IS NULL AND event_index IS NULL
                AND legacy_observed_height IS NOT NULL AND legacy_observed_height > 0)))),
    ADD CONSTRAINT defusion_reconciliation_boundary CHECK (
        (reconciled_height IS NULL AND retired_height IS NULL)
        OR (reconciled_height IS NOT NULL AND chain_id IS NOT NULL
            AND reconciled_height >= COALESCE(block_height,legacy_observed_height)
            AND (retired_height IS NULL OR retired_height = reconciled_height)));
CREATE UNIQUE INDEX defusion_source_event_uidx ON structs.defusion(chain_id,block_height,tx_index,event_index,denom);
CREATE INDEX defusion_active_delegator_idx ON structs.defusion(delegator_address,chain_id) WHERE retired_height IS NULL;
CREATE INDEX defusion_active_validator_idx ON structs.defusion(validator_address,created_at DESC) WHERE retired_height IS NULL;
COMMENT ON TABLE structs.defusion IS
    'Historical operation receipts, not current staking balances or native entry IDs. Retired identified receipts remain as replay tombstones.';
COMMENT ON COLUMN structs.defusion.legacy_observed_height IS
    'Upper source-height bound captured by the single writer for unidentified legacy rows; not a fabricated source-event identity.';
COMMENT ON COLUMN structs.defusion.completed_at IS
    'Scheduled completion from the event, often second precision. Never proof of completion, release, or absence of a hold.';

ALTER TABLE sync_state.native_staking_snapshot ADD COLUMN receipts_pending BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX native_staking_receipts_pending_idx ON sync_state.native_staking_snapshot(chain_id,retry_after,address) WHERE receipts_pending;

CREATE VIEW structs.defusion_current AS
SELECT d.*,
    CASE WHEN d.block_height IS NULL THEN 'unidentified'
         WHEN d.reconciled_height IS NOT NULL AND s.complete AND s.source_height=d.reconciled_height THEN 'pending'
         ELSE 'unknown' END AS pending_state
FROM structs.defusion d
LEFT JOIN sync_state.native_staking_claim s ON s.chain_id=d.chain_id AND s.address=d.delegator_address
WHERE d.retired_height IS NULL;
COMMENT ON VIEW structs.defusion_current IS
    'Unretired receipts only. Pending means a compatible native operation group was present at reconciled_height; amount_p remains the original receipt amount, never a current claim. Unknown and unidentified are not zero.';
GRANT SELECT, INSERT, UPDATE ON structs.defusion TO structs_indexer;
GRANT SELECT ON structs.defusion_current TO structs_indexer, structs_webapp;

-- Native snapshot publication retires proven-absent receipts in its own
-- transaction. Wall time cannot establish absence (held entries may be overdue).
CREATE OR REPLACE PROCEDURE structs.CLEAN_DEFUSION()
AS $BODY$
BEGIN
    NULL;
END
$BODY$ LANGUAGE plpgsql SECURITY DEFINER;
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname='defusion_cleaner';
COMMIT;
