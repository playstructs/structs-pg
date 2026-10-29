-- Deploy structs-pg:table-native-staking-20261029-positions to pg
BEGIN;
ALTER TABLE sync_state.native_staking_snapshot ADD COLUMN positions_complete BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX native_staking_positions_pending_idx ON sync_state.native_staking_snapshot
    (chain_id,retry_after,address) WHERE NOT positions_complete;
CREATE TABLE sync_state.native_staking_position (
    chain_id TEXT NOT NULL,
    address VARCHAR NOT NULL,
    validator VARCHAR NOT NULL CHECK (validator <> ''),
    bonded NUMERIC NOT NULL CHECK (bonded >= 0 AND bonded < 'Infinity'::numeric AND bonded = trunc(bonded)),
    unbonding NUMERIC NOT NULL CHECK (unbonding >= 0 AND unbonding < 'Infinity'::numeric AND unbonding = trunc(unbonding)),
    unbonding_entries INTEGER NOT NULL CHECK (unbonding_entries >= 0),
    PRIMARY KEY (chain_id,address,validator),
    FOREIGN KEY (chain_id,address) REFERENCES sync_state.native_staking_snapshot ON DELETE CASCADE
);
CREATE VIEW sync_state.native_staking_position_state AS
SELECT c.chain_id,c.address,c.source_height,c.required_height,
    c.complete AND s.positions_complete AS complete
FROM sync_state.native_staking_claim c
JOIN sync_state.native_staking_snapshot s USING(chain_id,address);
COMMENT ON VIEW sync_state.native_staking_position_state IS
    'Only complete address snapshots establish absent validator positions as zero. Stale/legacy/missing coverage remains unknown. Eligibility still needs current staking preflight.';
GRANT SELECT,INSERT,UPDATE,DELETE ON sync_state.native_staking_position TO structs_indexer;
GRANT SELECT ON sync_state.native_staking_position_state TO structs_indexer;
COMMIT;
