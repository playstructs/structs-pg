-- Deploy structs-pg:table-substation to pg

BEGIN;

CREATE  TABLE structs.substation (
	id CHARACTER VARYING PRIMARY KEY,

	owner CHARACTER VARYING,
	creator CHARACTER VARYING,

	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMIT;
