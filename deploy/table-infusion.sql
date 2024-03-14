-- Deploy structs-pg:table-infusion to pg

BEGIN;

CREATE TABLE structs.infusion (
    destination_type INTEGER,
    destination_id CHARACTER VARYING,

    player_id CHARACTER VARYING,
    address CHARACTER VARYING,

	fuel INTEGER,
	power INTEGER,

    commission NUMERIC,

    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL,
	PRIMARY KEY (destination_id, address)
); 

COMMIT;
