-- Deploy structs-pg:table-signer-role to pg

BEGIN;

    CREATE TYPE structs.signer_role_status AS ENUM(
        'stub',
        'generating',
        'pending',
        'ready'
    );

    CREATE TABLE signer.role (
        id SERIAL PRIMARY KEY,
        player_id CHARACTER VARYING,
        guild_id CHARACTER VARYING,
        status structs.signer_role_status,
        system_only BOOLEAN DEFAULT false,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at	TIMESTAMPTZ DEFAULT NOW()
    );

COMMIT;
