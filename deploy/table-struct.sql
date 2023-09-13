-- Deploy structs-pg:table-struct to pg

BEGIN;

CREATE TABLE structs.struct (
	id INTEGER PRIMARY KEY,
	type CHARACTER VARYING,
	owner CHARACTER VARYING,
	energy INTEGER,
	fuel INTEGER,
	load INTEGER,
	state CHARACTER VARYING,
	creator CHARACTER VARYING,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
