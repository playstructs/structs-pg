-- Deploy structs-pg:table-signer-account to pg

BEGIN;

CREATE TABLE signer.account (
    id SERIAL PRIMARY KEY,
    role_id INTEGER REFERENCES signer.role(id),
    name CHARACTER VARYING,
    address CHARACTER VARYING,
    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL
); 

COMMIT;
