-- Deploy structs-pg:table-planet to pg

BEGIN;

CREATE UNLOGGED TABLE structs.planet (
	id CHARACTER VARYING PRIMARY KEY,

	max_ore INTEGER,

	creator CHARACTER VARYING,
	owner CHARACTER VARYING,

    state JSONB,

	status CHARACTER VARYING,
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

COMMIT;
