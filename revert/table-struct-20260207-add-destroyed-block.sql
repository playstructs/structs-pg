-- Revert structs-pg:table-struct-20260207-add-destroyed-block from pg

BEGIN;

    ALTER TABLE structs.struct DROP COLUMN IF EXISTS destroyed_block;

COMMIT;
