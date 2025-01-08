-- Deploy structs-pg:table-reactor to pg

BEGIN;

CREATE UNLOGGED TABLE structs.reactor (
	id CHARACTER VARYING PRIMARY KEY,
	validator CHARACTER VARYING,

	guild_id CHARACTER VARYING,

    default_commission NUMERIC,

	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMIT;
