-- Revert structs-pg:table-struct-20260810-idx-owner from pg

BEGIN;

    DROP INDEX IF EXISTS structs.struct_owner_idx;

COMMIT;
