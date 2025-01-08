-- Deploy structs-pg:table-signer-role to pg

BEGIN;

    CREATE TABLE signer.role (
        id CHARACTER VARYING PRIMARY KEY,
        label CHARACTER VARYING,

        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at	TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

COMMIT;
