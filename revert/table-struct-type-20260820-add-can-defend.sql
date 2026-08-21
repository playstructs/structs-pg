-- Revert structs-pg:table-struct-type-20260820-add-can-defend from pg

BEGIN;

    ALTER TABLE structs.struct_type
        DROP COLUMN IF EXISTS can_defend;

COMMIT;
