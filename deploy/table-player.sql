-- Deploy structs-pg:table-player to pg

BEGIN;

CREATE TABLE structs.player (
	id INTEGER PRIMARY KEY,
	username CHARACTER VARYING,
	pfp CHARACTER VARYING,
	guild_id INTEGER REFERENCES structs.guild(id),
	substation_id INTEGER REFERENCES structs.substation(id),
	planet_id   INTEGER REFERENCES structs.planet(id),
	load INTEGER,
	storage jsonb,
	status CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL,
	updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
