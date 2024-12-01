-- Deploy structs-pg:table-signer-account to pg

BEGIN;

    CREATE TYPE structs.account_status AS ENUM(
        'offline',
        'online',
        'new',
        'pending_registration'
    );

    CREATE TABLE signer.account (
        id SERIAL PRIMARY KEY,
        role_id CHARACTER VARYING REFERENCES signer.role(id),
        address CHARACTER VARYING,
        status structs.account_status,
        created_at TIMESTAMPTZ NOT NULL,
        updated_at	TIMESTAMPTZ NOT NULL
    );

    CREATE OR REPLACE FUNCTION signer.CLAIM_ACCOUNT(requested_role_id CHARACTER VARYING) RETURNS json AS
    $BODY$
    DECLARE
        claimed_account RECORD;
    BEGIN

        WITH pending_account AS MATERIALIZED (
            SELECT *
            FROM signer.account
            WHERE
                status = 'offline'
                AND role_id = requested_role_id
            ORDER BY updated_at ASC
            LIMIT 1 FOR UPDATE SKIP LOCKED
        )
        UPDATE signer.tx
        SET status     = 'online',
            updated_at = NOW()
        WHERE id = ANY (SELECT id FROM pending_account)
        RETURNING * INTO claimed_account; -- to_json(tx) INTO claimed_account;

        IF claimed_account IS NULL THEN
            INSERT INTO signer.account (role_id, status, created_at, updated_at)
                VALUES(requested_role_id, 'new', NOW(), NOW())
                    RETURNING * INTO claimed_account;
        END IF;

        RETURN to_json(claimed_account);
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.PENDING_ACCOUNT(account_id INTEGER, new_address CHARACTER VARYING) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.account SET address=new_address, status='pending_registration' WHERE id=account_id;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;




COMMIT;
