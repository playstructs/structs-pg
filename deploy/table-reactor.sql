-- Deploy structs-pg:table-reactor to pg

BEGIN;

CREATE TABLE structs.reactor (
	id INTEGER PRIMARY KEY,
	address CHARACTER VARYING, 
	moniker CHARACTER VARYING,
	guild INTEGER, 
	status CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL
);

COMMIT;
