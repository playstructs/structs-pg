-- Deploy structs-pg:table-ledger-20261029-denomination-identity to pg
-- Paired writer transition: stop sync-state, opt in with PGOPTIONS, migrate,
-- then start the writer whose conflict target includes denom. Ordinary
-- additive migrations do not require this gate.
BEGIN;
DO $$
BEGIN
    IF current_setting('structs.ledger_writer_contract', TRUE) IS DISTINCT FROM 'denomination-v1' THEN
        RAISE EXCEPTION 'paired ledger writer switch required: stop the writer and explicitly select denomination-v1 before deploying this change';
    END IF;
END $$;
SET LOCAL lock_timeout = '5s';
LOCK TABLE structs.ledger IN ACCESS EXCLUSIVE MODE;
ALTER TABLE structs.ledger ADD CONSTRAINT ledger_source_denom_required
    CHECK (chain_id IS NULL OR (denom IS NOT NULL AND denom <> ''));
CREATE UNIQUE INDEX ledger_source_event_denom_uidx
    ON structs.ledger (time, chain_id, tx_index, msg_index, event_index, denom);
DROP INDEX structs.ledger_source_event_uidx;
ALTER INDEX structs.ledger_source_event_denom_uidx RENAME TO ledger_source_event_uidx;
COMMENT ON INDEX structs.ledger_source_event_uidx IS
    'denomination-v1: exact source time/coordinates plus denomination. Semantic legs keep their original event_index encoding.';
GRANT SELECT, INSERT ON structs.ledger TO structs_indexer;
COMMIT;
