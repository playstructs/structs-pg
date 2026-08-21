-- Verify structs-pg:table-ledger-20260820-api-read-indexes on pg

BEGIN;

    DO $$
    DECLARE
        def text;
    BEGIN
        SELECT pg_get_indexdef(to_regclass('structs.ledger_address_time_id_idx'))
          INTO def;
        IF def IS NULL OR def NOT LIKE '%(address, "time" DESC, id DESC)%' THEN
            RAISE EXCEPTION 'ledger_address_time_id_idx definition unexpected: %', def;
        END IF;

        SELECT pg_get_indexdef(to_regclass('structs.ledger_action_denom_time_id_idx'))
          INTO def;
        IF def IS NULL OR def NOT LIKE '%(action, denom, "time" DESC, id DESC)%' THEN
            RAISE EXCEPTION 'ledger_action_denom_time_id_idx definition unexpected: %', def;
        END IF;
    END
    $$;

ROLLBACK;
