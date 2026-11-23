-- Verify structs-pg:guild-meta-webapp-20261123 on pg

BEGIN;

    SELECT webapp FROM structs.guild_meta WHERE FALSE;

    DO $$
    BEGIN
        IF pg_get_functiondef('structs.guild_metadata_update(character varying,jsonb,boolean)'::regprocedure)
           NOT LIKE '%webapp = EXCLUDED.webapp%' THEN
            RAISE EXCEPTION 'guild metadata updater must refresh webapp';
        END IF;
    END
    $$;

ROLLBACK;
