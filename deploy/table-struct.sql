-- Deploy structs-pg:table-struct to pg

BEGIN;

CREATE UNLOGGED TABLE structs.struct (
	id CHARACTER VARYING PRIMARY KEY,
	index INTEGER,

	type INTEGER,
	creator CHARACTER VARYING,
	owner CHARACTER VARYING,

    location_type CHARACTER VARYING,
    location_id CHARACTER VARYING,
    operating_ambit CHARACTER VARYING,
    slot INTEGER,

    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNLOGGED TABLE structs.struct_attribute (
    id          CHARACTER VARYING PRIMARY KEY,
    val         INTEGER,
    updated_at	TIMESTAMPTZ NOT NULL
);

CREATE TABLE structs.struct_defender (
    defending_struct_id   CHARACTER VARYING PRIMARY KEY,
    protected_struct_id   CHARACTER VARYING,
    updated_at	TIMESTAMPTZ NOT NULL
);

COMMIT;
