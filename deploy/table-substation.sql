-- Deploy structs-pg:table-substation to pg

BEGIN;

CREATE TABLE structs.substation (
	id CHARACTER VARYING PRIMARY KEY,

	owner CHARACTER VARYING,
	creator CHARACTER VARYING,

	created_at TIMESTAMPTZ NOT NULL,
	updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
