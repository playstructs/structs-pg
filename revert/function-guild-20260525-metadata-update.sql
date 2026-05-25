-- Revert structs-pg:function-guild-20260525-metadata-update from pg

BEGIN;

    DROP FUNCTION IF EXISTS structs.GUILD_METADATA_UPDATE(CHARACTER VARYING, JSONB, BOOLEAN);

    CREATE OR REPLACE FUNCTION structs.GUILD_METADATA_UPDATE(_guild_id CHARACTER VARYING, _payload JSONB) RETURNS VOID AS
    $BODY$
    BEGIN
        INSERT INTO structs.guild_meta
            VALUES (
                   _guild_id,
                   _payload->'guild'->>'name',
                   _payload->'guild'->>'description',
                   _payload->'guild'->>'tag',
                   _payload->'guild'->>'logo',
                   _payload->'guild'->'socials',
                   _payload->'guild'->'denom',
                   _payload->'guild'->'services',
                   _payload->'guild'->'domain',
                   _payload->'guild'->>'website',
                   coalesce(nullif((_payload->'guild'->>'baseEnergy'),''),'0')::NUMERIC,
                   'f',
                   '',
                   NOW(),
                   NOW()
               ) ON CONFLICT (id) DO UPDATE
            SET
                name = EXCLUDED.name,
                description = EXCLUDED.description,
                tag = EXCLUDED.tag,
                logo = EXCLUDED.logo,
                socials = EXCLUDED.socials,
                domain = EXCLUDED.domain,
                denom = EXCLUDED.denom,
                services = EXCLUDED.services,
                website = EXCLUDED.website,
                base_energy = EXCLUDED.base_energy,
                updated_at = EXCLUDED.updated_at;
    END
    $BODY$
    LANGUAGE plpgsql SECURITY DEFINER VOLATILE COST 100;

    GRANT EXECUTE ON FUNCTION structs.GUILD_METADATA_UPDATE(CHARACTER VARYING, JSONB) TO structs_crawler;

COMMIT;
