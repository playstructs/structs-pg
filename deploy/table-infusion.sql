-- Deploy structs-pg:table-infusion to pg

BEGIN;

CREATE  TABLE structs.infusion (
    destination_id CHARACTER VARYING,
    address CHARACTER VARYING,

    destination_type CHARACTER VARYING,
    player_id CHARACTER VARYING,

	fuel INTEGER,
    defusing INTEGER,
	power INTEGER,
    ratio INTEGER,

    commission NUMERIC,

    created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at	TIMESTAMPTZ DEFAULT NOW(),
	PRIMARY KEY (destination_id, address)
); 

COMMIT;
