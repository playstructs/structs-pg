-- Deploy structs-pg:table-planet to pg

BEGIN;

    CREATE UNLOGGED TABLE structs.planet (
        id CHARACTER VARYING PRIMARY KEY,

        max_ore INTEGER,

        creator CHARACTER VARYING,
        owner CHARACTER VARYING,

        map jsonb,

        space_slots INTEGER,
        air_slots INTEGER,
        land_slots INTEGER,
        water_slots INTEGER,

        status CHARACTER VARYING,

        location_list_start CHARACTER VARYING,
        location_list_end CHARACTER VARYING,

        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
    );

    CREATE TABLE structs.planet_meta (
        id CHARACTER VARYING,
        guild_id CHARACTER VARYING,
        name CHARACTER VARYING,

        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL,
        PRIMARY KEY (id, guild_id)
    );

    CREATE UNLOGGED TABLE structs.planet_attribute (
       id               CHARACTER VARYING PRIMARY KEY,
       object_id        CHARACTER VARYING,
       object_type      CHARACTER VARYING,
       attribute_type   CHARACTER VARYING,
       val              INTEGER,
       updated_at	    TIMESTAMPTZ NOT NULL
    );


    CREATE TABLE structs.planet_raid (
        id SERIAL PRIMARY KEY,
        fleet_id CHARACTER VARYING,
        planet_id CHARACTER VARYING,
        status CHARACTER VARYING,
        created_at TIMESTAMPTZ NOT NULL

    );

    CREATE TABLE structs.planet_activity_sequence (
        planet_id CHARACTER VARYING PRIMARY KEY,
        counter INTEGER NOT NULL DEFAULT 0
    );

    CREATE OR REPLACE FUNCTION structs.GET_PLANET_ACTIVITY_SEQUENCE(character varying) RETURNS integer AS
    $BODY$
        --This update sucks because it requires an insert exist
        --UPDATE structs.planet_activity_sequence
        --    SET counter = counter + 1
        --    WHERE planet_id = $1
        --    RETURNING counter

        INSERT INTO structs.planet_activity_sequence
            VALUES($1, 0)
            ON CONFLICT (planet_id) DO UPDATE SET counter = planet_activity_sequence.counter + 1
            RETURNING counter;
    $BODY$
    LANGUAGE sql VOLATILE;


    CREATE TABLE structs.planet_activity (
        time TIMESTAMPTZ NOT NULL,
        seq INTEGER NOT NULL,
        planet_id CHARACTER VARYING NOT NULL,
        category structs.grass_category,
        detail jsonb
    );

    SELECT create_hypertable('structs.planet_activity', by_range('time'));


COMMIT;
