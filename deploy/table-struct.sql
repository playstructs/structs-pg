-- Deploy structs-pg:table-struct to pg

BEGIN;

CREATE TABLE structs.struct (
	id INTEGER PRIMARY KEY,
	type CHARACTER VARYING,
	owner CHARACTER VARYING,
	state CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL,
	created_by CHARACTER VARYING
);


COMMIT;
