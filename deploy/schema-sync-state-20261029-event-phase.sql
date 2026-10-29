-- Deploy structs-pg:schema-sync-state-20261029-event-phase to pg
BEGIN;
-- Preserve the old bootstrap table and its existing source coordinates.
CREATE TABLE IF NOT EXISTS sync_state.infusion_event_position (
    destination_id VARCHAR NOT NULL,
    address VARCHAR NOT NULL,
    height BIGINT NOT NULL,
    tx_index INT NOT NULL,
    event_index INT NOT NULL,
    PRIMARY KEY (destination_id, address)
);
ALTER TABLE sync_state.infusion_event_position ADD COLUMN phase SMALLINT
    CHECK (phase BETWEEN 0 AND 3);
COMMENT ON COLUMN sync_state.infusion_event_position.phase IS
    '0=PreBlock, 1=BeginBlock, 2=transaction, 3=EndBlock. NULL is legacy unknown order, not PreBlock.';
CREATE TABLE sync_state.economy_event_position (
    family TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    height BIGINT NOT NULL CHECK (height > 0),
    phase SMALLINT NOT NULL CHECK (phase BETWEEN 0 AND 3),
    tx_index INT NOT NULL CHECK (tx_index >= -1),
    event_index INT NOT NULL CHECK (event_index >= 0),
    CHECK ((phase = 2 AND tx_index >= 0) OR (phase <> 2 AND tx_index = -1)),
    PRIMARY KEY (family, entity_id)
);
GRANT USAGE ON SCHEMA sync_state TO structs_indexer;
GRANT SELECT, INSERT, UPDATE, DELETE ON sync_state.infusion_event_position,
    sync_state.economy_event_position TO structs_indexer;
COMMIT;
