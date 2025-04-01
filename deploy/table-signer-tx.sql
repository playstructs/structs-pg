-- Deploy structs-pg:table-signer-tx to pg

BEGIN;

    CREATE TYPE structs.signer_tx_status AS ENUM(
        'pending',
        'claimed',
        'broadcast',
        'error'
    );

    CREATE TYPE structs.signer_tx_module AS ENUM(
        'structs',
        'bank',
        'staking',
        'auth',
        'authz'
    );

    CREATE TYPE structs.signer_tx_type AS ENUM (
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
        object_id CHARACTER VARYING,
        permission_requirement INTEGER,
        priority INTEGER DEFAULT 10,
        account_id INTEGER,
        module structs.signer_tx_module NOT NULL,
        command structs.signer_tx_type NOT NULL,
        args JSONB,
        flags JSONB,
        status structs.signer_tx_status DEFAULT 'pending',
        output TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at	TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE OR REPLACE FUNCTION signer.CREATE_TRANSACTION(
        _object_id CHARACTER VARYING,
        _permission_requirement INTEGER,
        _module structs.signer_tx_module,
        _command structs.signer_tx_type,
        _args JSONB,
        _flags JSONB
    ) RETURNS JSONB AS
    $BODY$
    DECLARE
        new_transaction RECORD;
    BEGIN
        INSERT INTO signer.tx(object_id, permission_requirement, module, command,  args, flags)
            VALUES(_object_id, _permission_requirement, _module, _command, _args, _flags)
            RETURNING * INTO new_transaction;

        RETURN to_jsonb(new_transaction);
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.CLAIM_INTERNAL_TRANSACTION() RETURNS JSONB AS
    $BODY$
    DECLARE
        claimed_tx RECORD;
    BEGIN

        WITH base_role AS (
            SELECT
                account.address as address,
                permission.val as permission,
                permission.player_id as object_id
            FROM
                signer.account,
                structs.permission
            WHERE account.address = permission.object_index
        ), address_permission AS (
            SELECT
              base_role.address as address,
              base_role.permission & permission.val as permission,
              permission.object_id as object_id
            FROM structs.permission, base_role
            WHERE permission.player_id = base_role.object_id
            UNION
            SELECT * FROM base_role
          ), pending_transaction AS MATERIALIZED (
                SELECT *
                FROM signer.tx
                WHERE
                        status = 'pending'
                  AND object_id IN (
                    SELECT address_permission.object_id
                    FROM address_permission
                    WHERE (address_permission.permission & tx.permission_requirement) > 0
                )
                ORDER BY updated_at ASC
                LIMIT 1 FOR UPDATE SKIP LOCKED
            )
            UPDATE signer.tx
            SET status     = 'claimed',
                -- account_id = <>,
                updated_at = NOW()
            WHERE id = ANY (SELECT id FROM pending_transaction)
            RETURNING * INTO claimed_tx;

        RETURN to_jsonb(claimed_tx);
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
