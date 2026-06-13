-- Revert structs-pg:type-grass-category-20260612-add-raid-shield-categories from pg

BEGIN;

    -- Enum values cannot be removed in PostgreSQL.
    -- These values will remain in the type but are unused after revert.

COMMIT;
