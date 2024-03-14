-- Deploy structs-pg:table-planet to pg

BEGIN;

CREATE TABLE structs.planet (
	id CHARACTER VARYING PRIMARY KEY,
	name CHARACTER VARYING,

	max_ore INTEGER,

	creator CHARACTER VARYING,
	owner CHARACTER VARYING,

    state JSONB,

	status CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
