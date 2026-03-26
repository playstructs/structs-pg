-- Revert structs-pg:table-signer-tx-20260325-add-tx-types from pg

BEGIN;

    -- Enum values cannot be removed in PostgreSQL.
    -- These values will remain in the type but are unused after revert.

COMMIT;
