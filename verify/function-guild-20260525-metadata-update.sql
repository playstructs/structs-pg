-- Verify structs-pg:function-guild-20260525-metadata-update on pg

BEGIN;

    SELECT 'structs.guild_metadata_update(character varying, jsonb, boolean)'::regprocedure;

    DO $$
    DECLARE
        body text;
    BEGIN
        SELECT pg_get_functiondef('structs.guild_metadata_update(character varying,jsonb,boolean)'::regprocedure)
        INTO body;

        IF body NOT LIKE '%INSERT INTO structs.guild_meta (%' THEN
            RAISE EXCEPTION 'expected explicit column list in GUILD_METADATA_UPDATE';
        END IF;

        IF body NOT LIKE '%_this_infrastructure%' THEN
            RAISE EXCEPTION 'expected _this_infrastructure parameter usage';
        END IF;
    END
    $$;

ROLLBACK;
