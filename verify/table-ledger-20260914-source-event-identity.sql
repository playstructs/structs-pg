-- Verify structs-pg:table-ledger-20260914-source-event-identity on pg

BEGIN;

    SELECT chain_id, tx_index, msg_index, event_index
      FROM structs.ledger WHERE FALSE;

    DO $$
    DECLARE
        stats_target integer;
    BEGIN
        IF NOT EXISTS (
            SELECT 1
              FROM pg_index i
              JOIN pg_class c ON c.oid = i.indexrelid
             WHERE c.relname = 'ledger_source_event_uidx'
               AND i.indrelid = 'structs.ledger'::regclass
               AND i.indisunique
        ) THEN
            RAISE EXCEPTION 'expected unique index ledger_source_event_uidx on structs.ledger';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_constraint
             WHERE conrelid = 'structs.ledger'::regclass
               AND conname = 'ledger_source_event_all_or_none_chk'
               AND contype = 'c'
        ) THEN
            RAISE EXCEPTION 'expected check constraint ledger_source_event_all_or_none_chk';
        END IF;

        SELECT attstattarget INTO stats_target
          FROM pg_attribute
         WHERE attrelid = 'structs.ledger'::regclass
           AND attname = 'address';
        IF stats_target IS DISTINCT FROM 1000 THEN
            RAISE EXCEPTION 'expected structs.ledger.address statistics target 1000, found %',
                stats_target;
        END IF;
    END
    $$;

ROLLBACK;
