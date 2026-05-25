-- Verify structs-pg:trigger-struct-type-20260525-sync-cheatsheet on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regprocedure('structs.struct_type_sync_cs()') IS NULL THEN
            RAISE EXCEPTION 'expected structs.STRUCT_TYPE_SYNC_CS() to exist';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_trigger t
              JOIN pg_class c ON c.oid = t.tgrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'structs'
               AND c.relname = 'struct_type'
               AND t.tgname = 'struct_type_sync_cs'
               AND NOT t.tgisinternal
        ) THEN
            RAISE EXCEPTION 'expected STRUCT_TYPE_SYNC_CS trigger on structs.struct_type';
        END IF;
    END
    $$;

ROLLBACK;
