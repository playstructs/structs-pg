-- Revert structs-pg:table-struct-defender-20260810-add-is-planetary from pg

BEGIN;

    ALTER TABLE structs.struct_defender DROP COLUMN IF EXISTS is_planetary;

COMMIT;
