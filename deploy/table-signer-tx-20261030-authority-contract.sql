-- Deploy structs-pg:table-signer-tx-20261030-authority-contract to pg
BEGIN;
SET LOCAL lock_timeout = '5s';

ALTER TABLE signer.tx
    ADD COLUMN contract TEXT,
    ADD COLUMN requested_player_id CHARACTER VARYING,
    ADD COLUMN chain_id TEXT,
    ADD COLUMN prepared_height BIGINT,
    ADD COLUMN claim_token UUID,
    ADD CONSTRAINT signer_tx_authority_context CHECK (
        (contract IS NULL AND requested_player_id IS NULL AND chain_id IS NULL
            AND prepared_height IS NULL AND claim_token IS NULL)
        OR (contract IS NOT NULL AND contract='v022-1' AND requested_player_id IS NOT NULL
            AND requested_player_id ~ '^1-[1-9][0-9]*$'
            AND chain_id IS NOT NULL AND chain_id='structstestnet-111'
            AND prepared_height IS NOT NULL AND prepared_height BETWEEN 3353000 AND 9007199254740991)
    );
CREATE INDEX signer_tx_v022_pending_idx ON signer.tx(updated_at,id)
    WHERE contract='v022-1' AND status='pending';
CREATE INDEX signer_role_player_idx ON signer.role(player_id,id);
CREATE INDEX signer_account_available_role_idx ON signer.account(role_id,updated_at,id)
    WHERE status='available';

-- Separate rows preserve independent gates; OR-ing masks on one object cannot
-- express provider access plus permission to spend another owner's collateral.
CREATE TABLE signer.tx_authority (
    tx_id INTEGER NOT NULL REFERENCES signer.tx(id) ON DELETE CASCADE,
    check_type TEXT NOT NULL CHECK (check_type IN ('object','object-owner','address-owner','provider-open')),
    object_id CHARACTER VARYING NOT NULL CHECK (length(object_id) BETWEEN 1 AND 128),
    permission INTEGER NOT NULL CHECK (permission BETWEEN 1 AND 33554431),
    PRIMARY KEY(tx_id,check_type,object_id,permission),
    CHECK (check_type <> 'provider-open' OR permission=262144)
);

CREATE FUNCTION signer.CREATE_TRANSACTION_V022(
    _player_id CHARACTER VARYING,
    _object_id CHARACTER VARYING,
    _module structs.signer_tx_module,
    _command structs.signer_tx_type,
    _args JSONB,
    _flags JSONB,
    _checks JSONB
) RETURNS JSONB AS
$BODY$
DECLARE
    _context RECORD;
    _tx signer.tx%ROWTYPE;
BEGIN
    IF _player_id IS NULL OR NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_player_id) THEN
        RAISE EXCEPTION 'requested signing player does not exist' USING ERRCODE='22023';
    END IF;
    -- Strings survive JSON/CLI transport without jq or JavaScript number loss.
    IF _args IS NULL OR jsonb_typeof(_args) <> 'array' THEN
        RAISE EXCEPTION 'transaction args must be a string array' USING ERRCODE='22023';
    END IF;
    IF jsonb_array_length(_args)>64 OR EXISTS (SELECT 1 FROM jsonb_array_elements(_args) a WHERE jsonb_typeof(a)<>'string') THEN
        RAISE EXCEPTION 'transaction args must be at most 64 exact strings' USING ERRCODE='22023';
    END IF;
    IF _flags IS NULL OR jsonb_typeof(_flags)<>'object' THEN
        RAISE EXCEPTION 'transaction flags must be a string object' USING ERRCODE='22023';
    END IF;
    IF (SELECT count(*) FROM jsonb_each(_flags))>64 OR EXISTS (
        SELECT 1 FROM jsonb_each(_flags) f WHERE jsonb_typeof(f.value)<>'string'
        OR f.key !~ '^[a-z][a-z0-9-]*$'
        OR f.key IN ('from','chain-id','node','home','yes','generate-only','offline','output',
            'broadcast-mode','gas','gas-adjustment','fees','gas-prices','timeout-height',
            'account-number','sequence','sign-mode','fee-payer','fee-granter')
        OR f.key LIKE 'keyring-%'
    ) THEN
        RAISE EXCEPTION 'invalid or worker-controlled transaction flags' USING ERRCODE='22023';
    END IF;
    IF _checks IS NULL OR jsonb_typeof(_checks)<>'array' THEN
        RAISE EXCEPTION 'transaction requires explicit authority checks' USING ERRCODE='22023';
    END IF;
    IF jsonb_array_length(_checks) NOT BETWEEN 1 AND 8 OR EXISTS (
        SELECT 1 FROM jsonb_array_elements(_checks) c WHERE jsonb_typeof(c)<>'object'
            OR NOT c ?& ARRAY['check_type','object_id','permission']
            OR (c - ARRAY['check_type','object_id','permission']) <> '{}'::jsonb
            OR jsonb_typeof(c->'check_type')<>'string' OR jsonb_typeof(c->'object_id')<>'string'
            OR jsonb_typeof(c->'permission')<>'number'
            OR (c->>'permission') !~ '^[1-9][0-9]{0,7}$'
    ) THEN
        RAISE EXCEPTION 'invalid transaction authority checks' USING ERRCODE='22023';
    END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol<>'v0.22.0' THEN
        RAISE EXCEPTION 'v0.22 indexed transaction context is not ready' USING ERRCODE='55000';
    END IF;
    INSERT INTO signer.tx(object_id,permission_requirement,module,command,args,flags,
        contract,requested_player_id,chain_id,prepared_height)
    VALUES(_object_id,0,_module,_command,_args,_flags,'v022-1',_player_id,_context.chain_id,_context.indexed_height::bigint)
    RETURNING * INTO _tx;
    INSERT INTO signer.tx_authority(tx_id,check_type,object_id,permission)
    SELECT _tx.id,c->>'check_type',c->>'object_id',(c->>'permission')::int
    FROM jsonb_array_elements(_checks) c;
    -- Kept for existing queue readers; selection uses each independent rule.
    UPDATE signer.tx SET permission_requirement=(SELECT bit_or(permission) FROM signer.tx_authority WHERE tx_id=_tx.id)
    WHERE id=_tx.id RETURNING * INTO _tx;
    RETURN to_jsonb(_tx);
END
$BODY$
LANGUAGE plpgsql VOLATILE;
REVOKE ALL ON FUNCTION signer.CREATE_TRANSACTION_V022(CHARACTER VARYING,CHARACTER VARYING,
    structs.signer_tx_module,structs.signer_tx_type,JSONB,JSONB,JSONB) FROM PUBLIC;

CREATE FUNCTION signer.TRANSACTION_AUTHORITY_CHECK(
    _address CHARACTER VARYING,
    _player_id CHARACTER VARYING,
    _check_type TEXT,
    _object_id CHARACTER VARYING,
    _permission INTEGER
) RETURNS BOOLEAN AS
$BODY$
DECLARE _owner CHARACTER VARYING;
BEGIN
    CASE _check_type
        WHEN 'object' THEN RETURN signer.PERMISSION_CHECK(_address,_object_id,_permission);
        WHEN 'object-owner' THEN
            _owner := signer.PERMISSION_OBJECT_OWNER(_object_id);
            IF _owner IS NULL OR split_part(_owner,'-',1) NOT IN ('0','1') THEN RETURN FALSE; END IF;
            RETURN signer.PERMISSION_CHECK(_address,_owner,_permission);
        WHEN 'address-owner' THEN
            RETURN EXISTS (SELECT 1 FROM structs.asset_owner ao WHERE ao.address=_object_id
                AND signer.PERMISSION_CHECK(_address,ao.owner_id,_permission));
        WHEN 'provider-open' THEN
            RETURN _permission=262144 AND signer.CAN_OPEN_AGREEMENT(_address,_object_id,_player_id);
        ELSE RETURN FALSE;
    END CASE;
END
$BODY$
LANGUAGE plpgsql STABLE;

CREATE FUNCTION signer.AUTHORIZED_ACCOUNTS_V022(_tx_id INTEGER)
RETURNS TABLE(account_id INTEGER,address CHARACTER VARYING,status structs.signer_account_status)
LANGUAGE sql STABLE AS
$BODY$
    SELECT a.id,a.address,a.status
    FROM signer.tx t
    JOIN signer.role r ON r.player_id=t.requested_player_id AND r.status='ready'
    JOIN signer.account a ON a.role_id=r.id
    JOIN structs.player_address pa ON pa.address=a.address AND pa.status='approved'
        AND pa.player_id=t.requested_player_id
    WHERE t.id=_tx_id AND t.contract='v022-1'
      AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
          AND signer.TRANSACTION_AUTHORITY_CHECK(a.address,t.requested_player_id,
              rule.check_type,rule.object_id,rule.permission) IS DISTINCT FROM TRUE);
$BODY$;

-- Reserve the transaction and its exact signing account in one database call.
-- No key is generated and no permission is granted as a side effect of a claim.
CREATE FUNCTION signer.CLAIM_TRANSACTION_V022() RETURNS JSONB AS
$BODY$
DECLARE
    _context RECORD;
    _tx signer.tx%ROWTYPE;
    _account signer.account%ROWTYPE;
    _visited INTEGER[] := ARRAY[]::INTEGER[];
    _attempt INTEGER;
BEGIN
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol<>'v0.22.0' THEN RETURN NULL; END IF;
    -- Another worker can lock a key after eligibility was read. Skip that
    -- request and consider a bounded number of other ready requests this call.
    FOR _attempt IN 1..32 LOOP
        -- Select one row at a time: a cursor loop may prefetch/lock other
        -- players' requests before returning its first successful claim.
        SELECT t.* INTO _tx FROM signer.tx t
        WHERE t.status='pending' AND t.contract='v022-1' AND t.id<>ALL(_visited)
          AND t.chain_id=_context.chain_id AND t.prepared_height<=_context.indexed_height::bigint
          AND EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(t.id) a WHERE a.status='available')
        ORDER BY t.updated_at,t.id LIMIT 1 FOR UPDATE OF t SKIP LOCKED;
        IF NOT FOUND THEN RETURN NULL; END IF;
        _visited := array_append(_visited,_tx.id);
        SELECT a.* INTO _account FROM signer.account a
        JOIN signer.AUTHORIZED_ACCOUNTS_V022(_tx.id) eligible ON eligible.account_id=a.id
        WHERE a.status='available' ORDER BY a.updated_at,a.id
        LIMIT 1 FOR UPDATE OF a SKIP LOCKED;
        IF NOT FOUND THEN CONTINUE; END IF;
        UPDATE signer.account SET status='signing',updated_at=NOW() WHERE id=_account.id RETURNING * INTO _account;
        UPDATE signer.tx SET status='claimed',account_id=_account.id,claim_token=gen_random_uuid(),updated_at=NOW()
        WHERE id=_tx.id RETURNING * INTO _tx;
        RETURN jsonb_build_object('transaction',to_jsonb(_tx),'account',to_jsonb(_account));
    END LOOP;
    RETURN NULL;
END
$BODY$
LANGUAGE plpgsql VOLATILE;
REVOKE ALL ON FUNCTION signer.CLAIM_TRANSACTION_V022() FROM PUBLIC;

-- Legacy workers may keep handling legacy rows during compatible preparation.
-- They must never infer v0.22 authority from the informational combined mask.
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
                  AND  tx.contract IS NULL
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

        IF EXISTS (SELECT 1 FROM signer.tx WHERE id=tx_id AND contract IS NOT NULL) THEN
            RETURN NULL;
        END IF;

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
COMMIT;
