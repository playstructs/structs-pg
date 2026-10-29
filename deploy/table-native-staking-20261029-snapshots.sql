-- Deploy structs-pg:table-native-staking-20261029-snapshots to pg
BEGIN;
-- A complete address-scoped native query is the evidence for these totals.
-- Historical ledger receipts and delayed infusion cleanup are not evidence.
CREATE TABLE sync_state.native_staking_snapshot (
    chain_id TEXT NOT NULL CHECK (chain_id <> ''),
    address VARCHAR NOT NULL CHECK (address <> ''),
    required_height BIGINT NOT NULL CHECK (required_height > 0),
    source_height BIGINT CHECK (source_height > 0),
    bonded NUMERIC CHECK (bonded >= 0 AND bonded < 'Infinity'::numeric AND bonded = trunc(bonded)),
    unbonding NUMERIC CHECK (unbonding >= 0 AND unbonding < 'Infinity'::numeric AND unbonding = trunc(unbonding)),
    fetched_at TIMESTAMPTZ,
    retry_after TIMESTAMPTZ NOT NULL DEFAULT '-infinity',
    pending BOOLEAN GENERATED ALWAYS AS (source_height IS NULL OR source_height < required_height) STORED,
    CHECK ((source_height IS NULL AND bonded IS NULL AND unbonding IS NULL AND fetched_at IS NULL)
        OR (source_height IS NOT NULL AND bonded IS NOT NULL AND unbonding IS NOT NULL AND fetched_at IS NOT NULL)),
    PRIMARY KEY (chain_id, address)
);
CREATE INDEX native_staking_snapshot_pending_idx
    ON sync_state.native_staking_snapshot (chain_id, retry_after, address) WHERE pending;

-- Include both validators of an in-flight redelegation: a source slash can
-- change destination stake after the source delegation itself has disappeared.
CREATE TABLE sync_state.native_staking_exposure (
    chain_id TEXT NOT NULL,
    validator VARCHAR NOT NULL CHECK (validator <> ''),
    address VARCHAR NOT NULL,
    PRIMARY KEY (chain_id, validator, address),
    FOREIGN KEY (chain_id, address) REFERENCES sync_state.native_staking_snapshot ON DELETE CASCADE
);
CREATE INDEX native_staking_exposure_address_idx
    ON sync_state.native_staking_exposure (chain_id, address);

-- A snapshot being fetched can discover exposure not present in the old index.
-- Retain validator changes even when no cached address is currently attached.
CREATE TABLE sync_state.native_staking_invalidation (
    chain_id TEXT NOT NULL CHECK (chain_id <> ''),
    validator VARCHAR NOT NULL,
    height BIGINT NOT NULL CHECK (height > 0),
    PRIMARY KEY (chain_id, validator)
);
COMMENT ON COLUMN sync_state.native_staking_invalidation.validator IS
    'Operator address; empty string is the chain-wide financial slash/upgrade watermark.';

CREATE VIEW sync_state.native_staking_claim AS
SELECT s.chain_id, s.address, s.required_height, s.source_height, s.fetched_at, evidence.complete,
       CASE WHEN evidence.complete THEN s.bonded END AS bonded,
       CASE WHEN evidence.complete THEN s.unbonding END AS unbonding
FROM sync_state.native_staking_snapshot s
CROSS JOIN LATERAL (SELECT NOT s.pending AND EXISTS (
    SELECT 1 FROM sync_state.sync_cursor c WHERE c.chain_id=s.chain_id AND c.last_height>=s.source_height
) AS complete) evidence;
COMMENT ON VIEW sync_state.native_staking_claim IS
    'Current native claims only after a complete snapshot satisfies the latest invalidation. Missing rows are unknown, not zero. Redelegations are exposure, never a second asset.';
GRANT SELECT, INSERT, UPDATE, DELETE ON sync_state.native_staking_snapshot,
    sync_state.native_staking_exposure, sync_state.native_staking_invalidation TO structs_indexer;
GRANT SELECT ON sync_state.native_staking_claim TO structs_indexer;
COMMIT;
