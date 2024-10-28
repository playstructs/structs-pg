-- Deploy structs-pg:table-allocation to pg

BEGIN;

CREATE UNLOGGED TABLE structs.allocation (
	id CHARACTER VARYING PRIMARY KEY,

    allocationType CHARACTER VARYING,

	source_id CHARACTER VARYING,
    index INTEGER,
	destination_id CHARACTER VARYING,

    creator CHARACTER VARYING,
    controller CHARACTER VARYING,
    locked boolean,

    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL  
); 

COMMIT;
