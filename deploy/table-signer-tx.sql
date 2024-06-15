-- Deploy structs-pg:table-signer-tx to pg

BEGIN;

CREATE TABLE signer.tx (
    id SERIAL PRIMARY KEY,
    role_id INTEGER,
    command CHARACTER VARYING,
    args jsonb,
    flags jsonb,
    status CHARACTER VARYING,
    created_at TIMESTAMPTZ NOT NULL,
	updated_at	TIMESTAMPTZ NOT NULL
); 

COMMIT;
