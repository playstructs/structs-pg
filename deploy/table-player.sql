-- Deploy structs-pg:table-player to pg

BEGIN;

CREATE TABLE structs.player (
	id INTEGER PRIMARY KEY,
	username CHARACTER VARYING,
	pfp CHARACTER VARYING,
	guild INTEGER REFERENCES structs.guild(id),
	substation INTEGER REFERENCES structs.substation(id),
	status CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL
);

COMMIT;
