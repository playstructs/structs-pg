-- Deploy structs-pg:table-address-tag to pg

BEGIN;

CREATE TABLE structs.address_tag (
	address CHARACTER VARYING PRIMARY KEY,
    label CHARACTER VARYING,
    entry CHARACTER VARYING,

    created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at	TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (address, label)
);

COMMIT;



