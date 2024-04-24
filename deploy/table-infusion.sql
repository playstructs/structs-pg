-- Deploy structs-pg:table-infusion to pg

BEGIN;

CREATE UNLOGGED TABLE structs.infusion (
    destination_id CHARACTER VARYING,
    address CHARACTER VARYING,

    destination_type CHARACTER VARYING,
    player_id CHARACTER VARYING,

	fuel INTEGER,
    defusing INTEGER,
	power INTEGER,
    ratio INTEGER,

    commission NUMERIC,

    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL,
	PRIMARY KEY (destination_id, address)
); 

COMMIT;
