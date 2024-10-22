-- Deploy structs-pg:table-fleet to pg

BEGIN;

CREATE TABLE structs.fleet (
	id CHARACTER VARYING PRIMARY KEY,
	owner CHARACTER VARYING,

    map jsonb,

    space_slots INTEGER,
    air_slots INTEGER,
    land_slots INTEGER,
    water_slots INTEGER,

    location_type CHARACTER VARYING,
    location_id CHARACTER VARYING,
	status CHARACTER VARYING,

	location_list_forward CHARACTER VARYING,
	location_list_backward CHARACTER VARYING,

    command_struct CHARACTER VARYING,

	created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
