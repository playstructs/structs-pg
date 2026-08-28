-- Revert structs-pg:table-signer-tx-20260825-add-v021-tx-types from pg

BEGIN;

    -- Enum values cannot be removed in PostgreSQL.
    -- The values remain in the type but are unused after revert.

COMMIT;
