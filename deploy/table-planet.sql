-- Deploy structs-pg:table-planet to pg

BEGIN;

CREATE TABLE structs.planet (
	id INTEGER PRIMARY KEY,
	type CHARACTER VARYING, 
	name CHARACTER VARYING,
	owner CHARACTER VARYING,
	status CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL
);

COMMIT;
