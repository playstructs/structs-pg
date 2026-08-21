-- Verify structs-pg:table-ledger-20260820-api-cursor-unique on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        SELECT pg_get_indexdef(to_regclass('structs.ledger_time_id_uidx'))
          INTO def;
        IF def IS NULL OR def NOT LIKE 'CREATE UNIQUE INDEX %("time", id)%' THEN
            RAISE EXCEPTION 'ledger_time_id_uidx definition unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
