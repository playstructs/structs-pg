-- Deploy structs-pg:table-guild to pg

BEGIN;

    CREATE  TABLE structs.guild (
        id CHARACTER VARYING PRIMARY KEY,
        index INTEGER,

        endpoint CHARACTER VARYING,

        join_infusion_minimum NUMERIC GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(join_infusion_minimum_p, 'ualpha')) STORED,
        join_infusion_minimum_p NUMERIC,
        join_infusion_minimum_bypass_by_request CHARACTER VARYING,
        join_infusion_minimum_bypass_by_invite CHARACTER VARYING,

        primary_reactor_id CHARACTER VARYING,
        entry_substation_id CHARACTER VARYING,

        creator CHARACTER VARYING,
        owner CHARACTER VARYING,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE structs.guild_meta (
        id CHARACTER VARYING PRIMARY KEY,

        name CHARACTER VARYING,
        description TEXT,
        tag CHARACTER VARYING,
        logo CHARACTER VARYING,
        socials jsonb,
        denom jsonb,
        services jsonb,
        domain CHARACTER VARYING,
        website CHARACTER VARYING,
        base_energy NUMERIC,
        this_infrastructure bool,
        status CHARACTER VARYING,

        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );



    CREATE  TABLE structs.guild_membership_application (
        guild_id CHARACTER VARYING,
        player_id CHARACTER VARYING,
        join_type CHARACTER VARYING,
        status CHARACTER VARYING,
        proposer CHARACTER VARYING,
        substation_id CHARACTER VARYING,

        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (guild_id, player_id)
    );


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

COMMIT;
