-- Deploy structs-pg:table-struct-type to pg

BEGIN;

CREATE TABLE structs.struct_type (
	id INTEGER PRIMARY KEY,
	type CHARACTER VARYING,
	name CHARACTER VARYING,
	description CHARACTER VARYING,
	created_at TIMESTAMPTZ NOT NULL
);


COMMIT;
