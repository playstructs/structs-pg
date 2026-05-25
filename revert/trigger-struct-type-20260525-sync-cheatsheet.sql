-- Revert structs-pg:trigger-struct-type-20260525-sync-cheatsheet from pg

BEGIN;

    DROP TRIGGER IF EXISTS STRUCT_TYPE_SYNC_CS ON structs.struct_type;
    DROP FUNCTION IF EXISTS structs.STRUCT_TYPE_SYNC_CS();

COMMIT;
