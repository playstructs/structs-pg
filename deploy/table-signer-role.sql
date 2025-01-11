-- Deploy structs-pg:table-signer-role to pg

BEGIN;

    CREATE TYPE structs.signer_role_status AS ENUM(
        'stub',
        'generating',
        'pending',
        'available',
        'signing'
    );

    CREATE TABLE signer.role (
        id SERIAL PRIMARY KEY,
        player_id CHARACTER VARYING,
        status structs.signer_role_status,

        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at	TIMESTAMPTZ DEFAULT NOW()
    );

COMMIT;
