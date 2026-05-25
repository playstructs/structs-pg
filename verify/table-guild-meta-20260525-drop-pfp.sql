-- Verify structs-pg:table-guild-meta-20260525-drop-pfp on pg

BEGIN;

    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1
              FROM information_schema.columns
             WHERE table_schema = 'structs'
               AND table_name = 'guild_meta'
               AND column_name = 'pfp'
        ) THEN
            RAISE EXCEPTION 'expected structs.guild_meta.pfp to be dropped';
        END IF;
    END
    $$;

    SELECT name FROM structs.guild_meta WHERE FALSE;

ROLLBACK;
