-- Deploy structs-pg:function-guild-20260525-metadata-update to pg
--
-- Replace positional INSERT with explicit column list and add
-- _this_infrastructure parameter (insert-only; not updated on conflict).

BEGIN;

    DROP FUNCTION IF EXISTS structs.GUILD_METADATA_UPDATE(CHARACTER VARYING, JSONB);

    CREATE OR REPLACE FUNCTION structs.GUILD_METADATA_UPDATE(
        _guild_id CHARACTER VARYING,
        _payload JSONB,
        _this_infrastructure BOOLEAN
    ) RETURNS VOID AS
    $BODY$
    BEGIN
        INSERT INTO structs.guild_meta (
            id,
            name,
            description,
            tag,
            logo,
            socials,
            denom,
            services,
            domain,
            website,
            base_energy,
            this_infrastructure,
            status,
            created_at,
            updated_at
        ) VALUES (
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
            coalesce(nullif((_payload->'guild'->>'baseEnergy'), ''), '0')::NUMERIC,
            _this_infrastructure,
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

    GRANT EXECUTE ON FUNCTION structs.GUILD_METADATA_UPDATE(CHARACTER VARYING, JSONB, BOOLEAN) TO structs_crawler;

COMMIT;
