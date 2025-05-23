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

    CREATE OR REPLACE FUNCTION signer.CREATE_SYSTEM_ROLE(_username CHARACTER VARYING, _guild_id CHARACTER VARYING, _address CHARACTER VARYING) RETURNS void AS
    $BODY$
    DECLARE
        _role_id INTEGER;
    BEGIN
        INSERT INTO structs.player_internal_pending(username, guild_id, primary_address) VALUES(_username, _guild_id, _address) RETURNING role_id INTO _role_id;

        INSERT INTO signer.account(role_id, address, status) VALUES (_role_id, _address, 'pending');
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;

    CREATE OR REPLACE FUNCTION signer.CLAIM_ROLE_STUB() RETURNS JSONB AS
    $BODY$
    DECLARE
        claimed_role RECORD;
    BEGIN
        WITH role_stub AS MATERIALIZED (
            SELECT *
            FROM signer.role
            WHERE status = 'stub'
            ORDER BY updated_at ASC
            LIMIT 1 FOR UPDATE SKIP LOCKED
        )
        UPDATE signer.role
        SET status     = 'generating',
            updated_at = NOW()
        WHERE id = ANY (SELECT id FROM role_stub)
        RETURNING * INTO claimed_role;

        RETURN to_jsonb(claimed_role);
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.SET_PLAYER_INTERNAL_PENDING_PRIMARY_ADDRESS(_role_id INTEGER, _primary_address CHARACTER VARYING) RETURNS void AS
    $BODY$
    BEGIN
        UPDATE structs.player_internal_pending SET primary_address = _primary_address WHERE role_id=_role_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


COMMIT;
