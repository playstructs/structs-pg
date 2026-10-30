-- Revert structs-pg:table-signer-tx-20261030-authority-contract from pg
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE signer.tx IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract IS NOT NULL) THEN
        RAISE EXCEPTION 'versioned signer requests exist; retain their authority context or restore a verified checkpoint';
    END IF;
END $$;
CREATE OR REPLACE FUNCTION signer.claim_internal_transaction()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
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
        ), object_owners AS (
            SELECT
                base_role.address as address,
                base_role.permission as permission,
                player_object.object_id as object_id
            FROM
                structs.player_object, base_role
            WHERE player_object.player_id = base_role.object_id
        ), address_permission AS (
            SELECT
              base_role.address as address,
              base_role.permission & permission.val as permission,
              permission.object_id as object_id
            FROM structs.permission, base_role
            WHERE permission.player_id = base_role.object_id
            UNION
            SELECT * FROM object_owners
            UNION
            SELECT * FROM base_role
          ), pending_transaction AS MATERIALIZED (
                SELECT *
                FROM signer.tx
                WHERE
                        status = 'pending'
                  AND  object_id IN (SELECT address_permission.object_id
                                          FROM address_permission
                                          WHERE (address_permission.permission & tx.permission_requirement) = tx.permission_requirement)
                ORDER BY updated_at ASC
                LIMIT 1 FOR UPDATE SKIP LOCKED
            )
            UPDATE signer.tx
            SET status     = 'claimed',
                updated_at = NOW()
            WHERE id = ANY (SELECT id FROM pending_transaction)
            RETURNING * INTO claimed_tx;

        RETURN to_jsonb(claimed_tx);
    END
    $function$
;
CREATE OR REPLACE FUNCTION signer.claim_internal_account(tx_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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
            ), object_owners AS (
                SELECT
                    base_role.address as address,
                    base_role.permission as permission,
                    player_object.object_id as object_id
                FROM
                    structs.player_object, base_role
                WHERE player_object.player_id = base_role.object_id
            ), address_permission AS (
                SELECT *
                FROM (
                        SELECT base_role.address                     as address,
                               base_role.permission & permission.val as permission,
                               permission.object_id                  as object_id
                        FROM structs.permission,
                             base_role
                        WHERE permission.player_id = base_role.object_id
                        UNION
                            SELECT * FROM object_owners
                        UNION
                            SELECT * FROM base_role
                    )
                WHERE
                    object_id = tx_object_id
                    AND (permission & tx_permission_requirement) = tx_permission_requirement
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
        RETURNING * INTO claimed_account;

        IF claimed_account IS NOT NULL THEN
            UPDATE signer.tx SET account_id = claimed_account.id WHERE id=tx_id;
        END IF;

        IF claimed_account IS NULL THEN
            IF (SELECT COUNT(1) FROM signer.account WHERE account.role_id in (select role.id from signer.role where role.player_id in (select permission.player_id from structs.permission WHERE permission.object_id = tx_object_id and (permission.val & tx_permission_requirement) = tx_permission_requirement)) AND status in ('stub','generating','pending')) = 0 THEN
                INSERT INTO signer.account (role_id, status, created_at, updated_at)
                    VALUES((select role.id from signer.role where role.player_id in (select permission.player_id from structs.permission WHERE permission.object_id = tx_object_id and (permission.val & tx_permission_requirement) = tx_permission_requirement) LIMIT 1), 'stub', NOW(), NOW())
                        RETURNING * INTO claimed_account;
            END IF;
        END IF;

        RETURN to_json(claimed_account);
    END
    $function$
;
DROP FUNCTION signer.CLAIM_TRANSACTION_V022();
DROP FUNCTION signer.AUTHORIZED_ACCOUNTS_V022(INTEGER);
DROP FUNCTION signer.TRANSACTION_AUTHORITY_CHECK(CHARACTER VARYING,CHARACTER VARYING,TEXT,CHARACTER VARYING,INTEGER);
DROP FUNCTION signer.CREATE_TRANSACTION_V022(CHARACTER VARYING,CHARACTER VARYING,
    structs.signer_tx_module,structs.signer_tx_type,JSONB,JSONB,JSONB);
DROP TABLE signer.tx_authority;
DROP INDEX signer.signer_tx_v022_pending_idx;
DROP INDEX signer.signer_role_player_idx;
DROP INDEX signer.signer_account_available_role_idx;
ALTER TABLE signer.tx DROP CONSTRAINT signer_tx_authority_context,
    DROP COLUMN contract,DROP COLUMN requested_player_id,DROP COLUMN chain_id,
    DROP COLUMN prepared_height,DROP COLUMN claim_token;
COMMIT;
