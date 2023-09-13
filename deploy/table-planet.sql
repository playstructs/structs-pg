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

    state JSONB,

	status CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
