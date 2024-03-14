-- Deploy structs-pg:table-player to pg

BEGIN;

CREATE TABLE structs.player (
	id CHARACTER VARYING PRIMARY KEY,
    index INTEGER,

	username CHARACTER VARYING,
	pfp CHARACTER VARYING,

    guild_id CHARACTER VARYING,
	substation_id CHARACTER VARYING,
	planet_id CHARACTER VARYING,

	storage jsonb,

	status CHARACTER VARYING,

	created_at TIMESTAMPTZ NOT NULL,
	updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
