-- Verify structs-pg:trigger-grass-player-20260525-drop-meta-notify on pg

BEGIN;

    DO $$
    BEGIN
        IF to_regprocedure('structs.player_meta_notify()') IS NOT NULL THEN
            RAISE EXCEPTION 'expected structs.PLAYER_META_NOTIFY() to be dropped';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_trigger t
              JOIN pg_class c ON c.oid = t.tgrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'structs'
               AND c.relname = 'player'
               AND t.tgname = 'player_notify'
               AND NOT t.tgisinternal
        ) THEN
            RAISE EXCEPTION 'expected PLAYER_NOTIFY trigger on structs.player';
        END IF;
    END
    $$;

ROLLBACK;
