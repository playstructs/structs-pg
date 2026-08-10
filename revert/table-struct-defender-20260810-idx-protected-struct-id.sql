-- Revert structs-pg:table-struct-defender-20260810-idx-protected-struct-id from pg

BEGIN;

    DROP INDEX IF EXISTS structs.struct_defender_protected_struct_id_idx;

COMMIT;
