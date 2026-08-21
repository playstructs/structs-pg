-- Revert structs-pg:table-ledger-20260820-api-cursor-unique from pg

BEGIN;

    DROP INDEX IF EXISTS structs.ledger_time_id_uidx;

COMMIT;
