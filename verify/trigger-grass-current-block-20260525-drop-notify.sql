-- Verify structs-pg:trigger-grass-current-block-20260525-drop-notify on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regprocedure('structs.current_block_notify()') IS NOT NULL THEN
            RAISE EXCEPTION 'expected structs.CURRENT_BLOCK_NOTIFY() to be dropped';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM pg_trigger t
              JOIN pg_class c ON c.oid = t.tgrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'structs'
               AND c.relname = 'current_block'
               AND t.tgname = 'current_block_notify'
               AND NOT t.tgisinternal
        ) THEN
            RAISE EXCEPTION 'expected CURRENT_BLOCK_NOTIFY trigger to be dropped from structs.current_block';
        END IF;

        IF to_regclass('structs.current_block') IS NULL THEN
            RAISE EXCEPTION 'expected structs.current_block table to remain';
        END IF;
    END
    $$;

ROLLBACK;
