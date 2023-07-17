-- Deploy structs-pg:table-guild to pg

BEGIN;

CREATE TABLE structs.guild (
	id INTEGER PRIMARY KEY,
	api CHARACTER VARYING,
	public_key CHARACTER VARYING,
	name CHARACTER VARYING,
	socials jsonb,
	website CHARACTER VARYING,
	this_infrastructure bool,
	status CHARACTER VARYING,
	created_by CHARACTER VARYING, 
	created_at TIMESTAMPTZ NOT NULL
);

COMMIT;
