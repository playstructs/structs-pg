-- Deploy structs-pg:table-agreement to pg

BEGIN;

CREATE TABLE structs.agreement (
	id CHARACTER VARYING PRIMARY KEY,

    provider_id CHARACTER VARYING,
    allocation_id CHARACTER VARYING,

    capacity NUMERIC,

    start_block NUMERIC,
    end_block NUMERIC,

    creator CHARACTER VARYING,
    owner CHARACTER VARYING,

    created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at	TIMESTAMPTZ DEFAULT NOW()
); 

COMMIT;



