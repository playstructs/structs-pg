-- Deploy structs-pg:table-planet to pg

BEGIN;

CREATE TABLE structs.planet (
	id INTEGER PRIMARY KEY,
	name CHARACTER VARYING,

	max_ore INTEGER,
	ore_remaining INTEGER,
	ore_stored INTEGER,

	creator CHARACTER VARYING,
	owner INTEGER,

	space INTEGER[],
	sky INTEGER[],
	land INTEGER[],
	water INTEGER[],

	space_slots INTEGER,
	sky_slots INTEGER,
	land_slots INTEGER,
	water_slots INTEGER,

	status CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
