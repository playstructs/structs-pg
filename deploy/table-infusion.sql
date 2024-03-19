-- Deploy structs-pg:table-infusion to pg

BEGIN;

CREATE TABLE structs.infusion (
    destination_id CHARACTER VARYING,
    address CHARACTER VARYING,

    destination_type INTEGER,
    player_id CHARACTER VARYING,


	fuel INTEGER,
	power INTEGER,

    commission NUMERIC,

    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL,
	PRIMARY KEY (destination_id, address)
); 

COMMIT;
