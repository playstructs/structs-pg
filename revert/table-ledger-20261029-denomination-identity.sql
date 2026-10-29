-- Revert structs-pg:table-ledger-20261029-denomination-identity from pg
-- Stop the writer first. Multi-denomination history cannot be collapsed.
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE structs.ledger IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM structs.ledger WHERE chain_id IS NOT NULL
        GROUP BY time,chain_id,tx_index,msg_index,event_index HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'multi-denomination ledger events exist; keep the paired writer/schema or restore a verified checkpoint';
    END IF;
END $$;
CREATE UNIQUE INDEX ledger_source_event_legacy_uidx
    ON structs.ledger (time, chain_id, tx_index, msg_index, event_index);
DROP INDEX structs.ledger_source_event_uidx;
ALTER INDEX structs.ledger_source_event_legacy_uidx RENAME TO ledger_source_event_uidx;
ALTER TABLE structs.ledger DROP CONSTRAINT ledger_source_denom_required;
COMMENT ON INDEX structs.ledger_source_event_uidx IS
    'Idempotency key for sync-state ledger writes: ON CONFLICT (time, chain_id, tx_index, msg_index, event_index) DO NOTHING.';
COMMIT;
