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



    CREATE TYPE structs.activity_category AS ENUM (
        'raid_status',
        'fleet_arrive',
        'fleet_advance',
        'fleet_depart',
        'struct_attack',
        'struct_defense_remove',
        'struct_defense_add',
        'struct_status',
        'struct_move',
        'struct_block_build_start',
        'struct_block_ore_mine_start',
        'struct_block_ore_refine_start'
    );

    CREATE TABLE structs.planet_activity (
        time TIMESTAMPTZ NOT NULL,
        id SERIAL PRIMARY KEY,
        planet_id CHARACTER VARYING NOT NULL,
        category structs.activity_category,
        detail jsonb
    );

    SELECT create_hypertable('structs.planet_activity', by_range('time'));



COMMIT;
