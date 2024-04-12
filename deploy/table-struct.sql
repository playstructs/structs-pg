-- Deploy structs-pg:table-struct to pg

BEGIN;

CREATE UNLOGGED TABLE structs.struct (
	id CHARACTER VARYING PRIMARY KEY,
	type CHARACTER VARYING,
	owner CHARACTER VARYING,

    state jsonb,
	creator CHARACTER VARYING,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

COMMIT;
