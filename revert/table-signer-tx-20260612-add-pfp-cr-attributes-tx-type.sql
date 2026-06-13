-- Revert structs-pg:table-signer-tx-20260612-add-pfp-cr-attributes-tx-type from pg

BEGIN;

    -- Enum values cannot be removed in PostgreSQL.
    -- The value remains in the type but is unused after revert.

COMMIT;
