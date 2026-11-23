-- Verify structs-pg:guild-meta-language-20261123 on pg
BEGIN;
SELECT language FROM structs.guild_meta WHERE FALSE;
DO $$ BEGIN
    IF pg_get_functiondef('structs.guild_metadata_update(character varying,jsonb,boolean)'::regprocedure)
       NOT LIKE '%language = EXCLUDED.language%' THEN
        RAISE EXCEPTION 'guild metadata updater must refresh language';
    END IF;
END $$;
ROLLBACK;
