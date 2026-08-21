-- Revert structs-pg:table-ledger-20260820-api-read-indexes from pg

BEGIN;

    DROP INDEX IF EXISTS structs.ledger_action_denom_time_id_idx;
    DROP INDEX IF EXISTS structs.ledger_address_time_id_idx;

COMMIT;
