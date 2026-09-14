-- Revert structs-pg:table-ledger-20260914-source-event-identity from pg

BEGIN;

    ALTER TABLE structs.ledger
        ALTER COLUMN address SET STATISTICS -1;

    DROP INDEX IF EXISTS structs.ledger_source_event_uidx;

    ALTER TABLE structs.ledger
        DROP CONSTRAINT IF EXISTS ledger_source_event_all_or_none_chk;

    ALTER TABLE structs.ledger
        DROP COLUMN IF EXISTS event_index,
        DROP COLUMN IF EXISTS msg_index,
        DROP COLUMN IF EXISTS tx_index,
        DROP COLUMN IF EXISTS chain_id;

COMMIT;
