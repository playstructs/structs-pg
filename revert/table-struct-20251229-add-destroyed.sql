-- Revert structs-pg:table-struct-20251229-add-destroyed from pg

BEGIN;

    ALTER TABLE structs.struct DROP COLUMN IF EXISTS is_destroyed;

COMMIT;
