-- Deploy structs-pg:table-signer-account to pg

BEGIN;

    CREATE TYPE structs.signer_account_status AS ENUM(
        'stub',
        'generating',
        'pending',
        'available',
        'signing'
    );

    CREATE TABLE signer.account (
        id SERIAL PRIMARY KEY,
        role_id INTEGER,
        address CHARACTER VARYING UNIQUE,
        status structs.signer_account_status,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at	TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE OR REPLACE FUNCTION signer.CLAIM_INTERNAL_ACCOUNT(tx_id INTEGER) RETURNS json AS
    $BODY$
    DECLARE
        claimed_account RECORD;

        tx_object_id CHARACTER VARYING;
        tx_permission_requirement INTEGER;
    BEGIN

        SELECT
            object_id, permission_requirement INTO tx_object_id, tx_permission_requirement
        FROM signer.tx
        WHERE tx.id = tx_id;

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
            SELECT *
            FROM (SELECT base_role.address                     as address,
                       base_role.permission & permission.val as permission,
                       permission.object_id                  as object_id
                FROM structs.permission,
                     base_role
                WHERE permission.player_id = base_role.object_id
                UNION
                SELECT *
                FROM base_role)
            WHERE
                object_id = tx_object_id
                AND (permission & tx_permission_requirement) > 0
        ), pending_account AS MATERIALIZED (
            SELECT *
            FROM signer.account
            WHERE
                    account.status = 'available'
                AND account.address IN (SELECT address_permission.address FROM address_permission)
            ORDER BY account.updated_at ASC
            LIMIT 1 FOR UPDATE SKIP LOCKED
        )
        UPDATE signer.account
        SET status     = 'signing',
            updated_at = NOW()
        WHERE id = ANY (SELECT id FROM pending_account)
        RETURNING * INTO claimed_account; -- to_json(tx) INTO claimed_account;

        IF claimed_account IS NOT NULL THEN
            UPDATE signer.tx SET account_id = claimed_account.id WHERE id=tx_id;
        END IF;

        IF claimed_account IS NULL THEN
            IF (SELECT COUNT(1) FROM signer.account WHERE account.role_id in (select role.id from signer.role where role.player_id in (select permission.player_id from structs.permission WHERE permission.object_id = tx_object_id and (permission.val & tx_permission_requirement) > 0)) AND status in ('stub','generating','pending')) = 0 THEN
                INSERT INTO signer.account (role_id, status, created_at, updated_at)
                    VALUES((select role.id from signer.role where role.player_id in (select permission.player_id from structs.permission WHERE permission.object_id = tx_object_id and (permission.val & tx_permission_requirement) > 0) LIMIT 1), 'stub', NOW(), NOW())
                        RETURNING * INTO claimed_account;
            END IF;
        END IF;

        RETURN to_json(claimed_account);
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.UPDATE_PENDING_ACCOUNT(_account_id INTEGER, _player_id CHARACTER VARYING, _address CHARACTER VARYING, _pubkey CHARACTER VARYING, _signature CHARACTER VARYING, _permission INTEGER) RETURNS VOID AS
    $BODY$
    BEGIN
        UPDATE signer.account SET address=_address, status='pending' WHERE id=_account_id;

        -- [address] [proof pubkey] [proof signature] [permissions]
        INSERT INTO signer.tx (object_id, command, args, permission_requirement )
            VALUES (_player_id, 'address-register', jsonb_build_array(_player_id, _address , _pubkey ,_signature , _permission),127);
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.CREATE_PENDING_ACCOUNT_FROM_ROLE(_role_id INTEGER, _address CHARACTER VARYING) RETURNS VOID AS
    $BODY$
    BEGIN
        INSERT INTO signer.account(role_id, address, status) VALUES (_role_id, _address, 'pending');
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE COST 100;

    CREATE OR REPLACE FUNCTION signer.GET_NEW_ACCOUNT() RETURNS jsonb AS
    $BODY$
    DECLARE
        new_account RECORD;
    BEGIN

        WITH pending_account AS MATERIALIZED (
            SELECT
                account.*
            FROM signer.account WHERE status='stub'
            LIMIT 1 FOR UPDATE SKIP LOCKED
        ), updated_account AS (
            UPDATE signer.account
            SET status     = 'generating',
                updated_at = NOW()
            WHERE id = ANY (SELECT id FROM pending_account)
            RETURNING *)
        SELECT * INTO new_account FROM (
            SELECT
                updated_account.*,
            (SELECT role.player_id FROM signer.role WHERE role.id = updated_account.role_id) as player_id
            FROM updated_account
        );

        RETURN to_jsonb(new_account);
    END
    $BODY$
        LANGUAGE plpgsql VOLATILE COST 100;


    CREATE OR REPLACE FUNCTION signer.LOAD_INTERNAL_ACCOUNTS(account_set JSONB, default_role_id CHARACTER VARYING) RETURNS VOID AS
    $BODY$
    BEGIN
        INSERT INTO signer.account(address, status, role_id)
            SELECT
                value->>'address' as address,
                CASE (SELECT count(1) FROM structs.player_address WHERE player_address.address = value->>'address')
                    WHEN 0 THEN 'pending_registration'
                    ELSE 'available'
                END,
                CASE (SELECT count(1) FROM structs.player_address WHERE player_address.address = value->>'address')
                    WHEN 0 THEN default_role_id
                    ELSE (SELECT player_address.player_id FROM structs.player_address WHERE player_address.address = value->>'address')
                END
            FROM
                jsonb_array_elements(account_set)
            ON CONFLICT (address) DO NOTHING;
    END
    $BODY$
    LANGUAGE plpgsql VOLATILE COST 100;



COMMIT;
