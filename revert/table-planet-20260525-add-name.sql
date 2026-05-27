-- Revert structs-pg:table-planet-20260525-add-name from pg

BEGIN;

    CREATE TABLE structs.planet_meta (
        id CHARACTER VARYING,
        guild_id CHARACTER VARYING,
        name TEXT DEFAULT structs.generate_planet_name(),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (id, guild_id)
    );

    INSERT INTO structs.planet_meta (id, guild_id, name, created_at, updated_at)
    SELECT
        p.id,
        owner.guild_id,
        p.name,
        p.created_at,
        p.updated_at
    FROM structs.planet p
    LEFT JOIN structs.player owner ON owner.id = p.owner
    WHERE owner.guild_id IS NOT NULL;

    ALTER TABLE structs.planet
        DROP COLUMN IF EXISTS name;

COMMIT;
