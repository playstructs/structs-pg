-- Deploy structs-pg:table-planet to pg

BEGIN;

CREATE TABLE structs.planet (
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

CREATE TABLE structs.planet_attribute (
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

COMMIT;
