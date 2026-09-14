-- Deploy structs-pg:table-ledger-20260914-source-event-identity to pg
--
-- Give every ledger row a durable source-event identity so sync-state can
-- write the ledger idempotently (INSERT ... ON CONFLICT DO NOTHING) and
-- maintain api_inventory as a running balance instead of re-summing history.
--
-- Identity is (chain_id, block, tx_index, msg_index, event_index), the same
-- tuple sync_state.handler_error_log already records. The block is carried
-- by the existing `time` column: every ledger row is stamped with the block
-- time, which TimescaleDB also requires in any unique index on this
-- hypertable. Events that are not part of a transaction use -1 for tx_index
-- and msg_index.
--
-- Columns stay nullable so rows written by the current sync-state keep
-- working during the cutover window. Rows with NULL identity never conflict
-- with each other (NULLS DISTINCT), so uniqueness only applies once
-- sync-state starts populating the identity. A CHECK constraint keeps the
-- identity all-or-nothing so a partially populated row cannot slip through.
--
-- Also raise the address statistics target: two addresses hold ~40% of all
-- ledger rows and the default 100-bucket histogram misestimates per-chunk row
-- counts by ~75x on the inventory recompute path.

BEGIN;

    ALTER TABLE structs.ledger
        ADD COLUMN chain_id    CHARACTER VARYING,
        ADD COLUMN tx_index    INTEGER,
        ADD COLUMN msg_index   INTEGER,
        ADD COLUMN event_index INTEGER;

    ALTER TABLE structs.ledger
        ADD CONSTRAINT ledger_source_event_all_or_none_chk CHECK (
            (chain_id IS NULL AND tx_index IS NULL
                AND msg_index IS NULL AND event_index IS NULL)
            OR
            (chain_id IS NOT NULL AND tx_index IS NOT NULL
                AND msg_index IS NOT NULL AND event_index IS NOT NULL)
        );

    CREATE UNIQUE INDEX ledger_source_event_uidx
        ON structs.ledger (time, chain_id, tx_index, msg_index, event_index);

    ALTER TABLE structs.ledger
        ALTER COLUMN address SET STATISTICS 1000;

    COMMENT ON COLUMN structs.ledger.chain_id IS
        'Source chain id of the event that produced this row. NULL on rows written before source-event identity existed.';
    COMMENT ON COLUMN structs.ledger.tx_index IS
        'Transaction index within the block, or -1 for begin/end-block events. NULL on legacy rows.';
    COMMENT ON COLUMN structs.ledger.msg_index IS
        'Message index within the transaction, or -1 when not applicable. NULL on legacy rows.';
    COMMENT ON COLUMN structs.ledger.event_index IS
        'Event index within the block/transaction event list. NULL on legacy rows.';
    COMMENT ON INDEX structs.ledger_source_event_uidx IS
        'Idempotency key for sync-state ledger writes: ON CONFLICT (time, chain_id, tx_index, msg_index, event_index) DO NOTHING.';

COMMIT;
