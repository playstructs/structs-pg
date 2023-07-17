-- Deploy structs-pg:table-substation to pg

BEGIN;

CREATE TABLE structs.substation (
	id INTEGER PRIMARY KEY,
	created_at TIMESTAMPTZ NOT NULL, 
	updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
