-- Deploy structs-pg:table-signer-role to pg

BEGIN;

CREATE TABLE signer.role (
    id SERIAL PRIMARY KEY,
    label CHARACTER VARYING,

    -- These two details dictate a unique level of access
    --
    -- Setting these won't change what they mean online,
    -- but can be used for searching for the right role
    player_id CHARACTER VARYING,
    address_permissions INTEGER,

    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL
); 

COMMIT;
