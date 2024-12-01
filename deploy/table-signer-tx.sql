-- Deploy structs-pg:table-signer-tx to pg

BEGIN;

    CREATE TYPE structs.tx_status AS ENUM(
        'pending',
        'claimed',
        'broadcast',
        'error'
    );

    CREATE TYPE structs.tx_type AS ENUM (
        'address-register',
        'address-revoke',
        'allocation-create',
        'allocation-delete',
        'allocation-transfer',
        'allocation-update',
        'fleet-move',
        'guild-create',
        'guild-membership',
        'guild-membership-invite',
        'guild-membership-invite-approve',
        'guild-membership-invite-deny',
        'guild-membership-join',
        'guild-membership-join-proxy',
        'guild-membership-kick',
        'guild-membership-request',
        'guild-membership-request-approve',
        'guild-membership-request-deny',
        'guild-membership-request-revoke',
        'guild-update-endpoint',
        'guild-update-entry-substation-id',
        'guild-update-join-infusion-minimum',
        'guild-update-join-infusion-minimum-by-invite',
        'guild-update-join-infusion-minimum-by-request',
        'guild-update-owner-id',
        'permission-grant-on-address',
        'permission-grant-on-object',
        'permission-revoke-on-address',
        'permission-revoke-on-object',
        'permission-set-on-address',
        'permission-set-on-object',
        'planet-explore',
        'planet-raid-complete',
        'planet-raid-compute',
        'player-update-primary-address',
        'struct-activate',
        'struct-attack',
        'struct-build-complete',
        'struct-build-compute',
        'struct-build-initiate',
        'struct-deactivate',
        'struct-defense-clear',
        'struct-defense-set',
        'struct-generator-infuse',
        'struct-mine-compute',
        'struct-move',
        'struct-ore-mine-complete',
        'struct-ore-refine-complete',
        'struct-refine-compute',
        'struct-stealth-activate',
        'struct-stealth-deactivate',
        'substation-allocation-connect',
        'substation-allocation-disconnect',
        'substation-create',
        'substation-delete',
        'substation-player-connect',
        'substation-player-disconnect',
        'substation-player-migrate'
    );


    CREATE TABLE signer.tx (
        id SERIAL PRIMARY KEY,
        role_id CHARACTER VARYING,
        account_id INTEGER,
        command structs.tx_type NOT NULL,
        args TEXT[],
        flags TEXT[],
        status structs.tx_status NOT NULL,
        output TEXT,
        created_at TIMESTAMPTZ NOT NULL,
        updated_at	TIMESTAMPTZ NOT NULL
    );

    CREATE OR REPLACE FUNCTION signer.CLAIM_TRANSACTION(claiming_role_id INTEGER, claiming_account_id INTEGER) RETURNS json AS
    $BODY$
    DECLARE
        claimed_tx JSON;
    BEGIN
        WITH pending_transaction AS MATERIALIZED (
            SELECT *
              FROM signer.tx
              WHERE
                status = 'pending'
                AND role_id = claiming_role_id
              ORDER BY updated_at ASC
              LIMIT 1 FOR UPDATE SKIP LOCKED
        )
        UPDATE signer.tx
        SET status     = 'claimed',
            account_id = claiming_account_id,
            updated_at = NOW()
        WHERE id = ANY (SELECT id FROM pending_transaction)
        RETURNING to_json(tx) INTO claimed_tx;

        RETURN claimed_tx;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.TRANSACTION_ERROR(transaction_id INTEGER, transaction_error TEXT) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.tx
        SET status      = 'error',
            output      = transaction_error,
            updated_at  = NOW()
        WHERE id = transaction_id;
    END $BODY$ LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.TRANSACTION_BROADCAST_RESULTS(transaction_id INTEGER, transaction_output TEXT) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.tx
        SET status      = 'broadcast',
            output      = transaction_output,
            updated_at  = NOW()
        WHERE id = transaction_id;
    END $BODY$ LANGUAGE plpgsql VOLATILE COST 100;



COMMIT;
