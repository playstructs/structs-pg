-- Deploy structs-pg:guild-meta-webapp-20261123 to pg

BEGIN;

    ALTER TABLE structs.guild_meta ADD COLUMN webapp CHARACTER VARYING;

    -- The original document's guild.webapp was not cached. Mark metadata stale
    -- so the crawler retrieves it on its next pass.
    UPDATE structs.guild_meta SET updated_at = NOW() - INTERVAL '2 days';

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
            webapp,
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
            _payload->'guild'->>'webapp',
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
                webapp = EXCLUDED.webapp,
                website = EXCLUDED.website,
                base_energy = EXCLUDED.base_energy,
                updated_at = EXCLUDED.updated_at;
    END
    $BODY$
    LANGUAGE plpgsql SECURITY DEFINER VOLATILE COST 100;

    GRANT EXECUTE ON FUNCTION structs.GUILD_METADATA_UPDATE(CHARACTER VARYING, JSONB, BOOLEAN) TO structs_crawler;

COMMIT;
