-- Deploy structs-pg:table-infusion to pg

BEGIN;

CREATE  TABLE structs.infusion (
    destination_id CHARACTER VARYING,
    address CHARACTER VARYING,

    destination_type CHARACTER VARYING,
    player_id CHARACTER VARYING,

	fuel NUMERIC GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(fuel_p, 'ualpha')) STORED,
    fuel_p NUMERIC,
    defusing NUMERIC GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(defusing_p, 'ualpha')) STORED,
    defusing_p NUMERIC,
	power NUMERIC  GENERATED ALWAYS AS (structs.UNIT_LEGACY_FORMAT(power_p, 'milliwatt')) STORED,
    power_p NUMERIC,

    ratio NUMERIC,

    commission NUMERIC,

    created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at	TIMESTAMPTZ DEFAULT NOW(),
	PRIMARY KEY (destination_id, address)
); 

COMMIT;
