-- Revert structs-pg:function-signer-tx-20261030-permission-mutation from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx,signer.tx_authority IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx_authority WHERE operation<>'' OR subject_id<>''
            OR check_type IN ('permission-address','permission-object'))
        OR EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1'
            AND command::text ~ '^permission-(grant|set|revoke)-on-(address|object)$') THEN
        RAISE EXCEPTION 'versioned permission requests exist; retain their contract or restore a verified checkpoint';
    END IF;
END $$;
CREATE TEMP TABLE signer_permission_function_acl ON COMMIT DROP AS
    SELECT p.proowner,p.proacl,v.source,v.target
    FROM (VALUES
            ('signer.tx_permission_grant_on_address(character varying,character varying,integer)','signer.tx_permission_grant_on_address(character varying,character varying,numeric)'),
            ('signer.tx_permission_grant_on_object(character varying,character varying,character varying,integer)','signer.tx_permission_grant_on_object(character varying,character varying,character varying,numeric)'),
            ('signer.tx_permission_revoke_on_address(character varying,character varying,integer)','signer.tx_permission_revoke_on_address(character varying,character varying,numeric)'),
            ('signer.tx_permission_revoke_on_object(character varying,character varying,character varying,integer)','signer.tx_permission_revoke_on_object(character varying,character varying,character varying,numeric)'),
            ('signer.tx_permission_set_on_address(character varying,character varying,integer)','signer.tx_permission_set_on_address(character varying,character varying,numeric)'),
            ('signer.tx_permission_set_on_object(character varying,character varying,character varying,integer)','signer.tx_permission_set_on_object(character varying,character varying,character varying,numeric)')
    ) v(source,target) JOIN pg_proc p ON p.oid=v.target::regprocedure;
CREATE OR REPLACE FUNCTION signer.tx_permission_grant_on_address(_player_id character varying, _address character varying, _permissions integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,_permissions,'structs','permission-grant-on-address',jsonb_build_array( _address, _permissions),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_permission_grant_on_object(_player_id character varying, _object_id character varying, _target_player_id character varying, _permissions integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,_permissions,'structs','permission-grant-on-object',jsonb_build_array( _object_id, _target_player_id, _permissions),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_permission_revoke_on_address(_player_id character varying, _address character varying, _permissions integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,_permissions,'structs','permission-revoke-on-address',jsonb_build_array( _address, _permissions),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_permission_revoke_on_object(_player_id character varying, _object_id character varying, _target_player_id character varying, _permissions integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,_permissions,'structs','permission-revoke-on-object',jsonb_build_array( _object_id, _target_player_id, _permissions),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_permission_set_on_address(_player_id character varying, _address character varying, _permissions integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_player_id,_permissions,'structs','permission-set-on-address',jsonb_build_array( _address, _permissions),'{}');
    END
    $function$
;

CREATE OR REPLACE FUNCTION signer.tx_permission_set_on_object(_player_id character varying, _object_id character varying, _target_player_id character varying, _permissions integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
    BEGIN
        PERFORM signer.CREATE_TRANSACTION(_object_id,_permissions,'structs','permission-set-on-object',jsonb_build_array( _object_id, _target_player_id, _permissions),'{}');
    END
    $function$
;
DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT saved.proowner,saved.proacl,saved.source AS target FROM pg_temp.signer_permission_function_acl saved
    LOOP
        target := f.target::regprocedure;
        EXECUTE format('ALTER FUNCTION %s OWNER TO %I',target,pg_get_userbyid(f.proowner));
        -- Clear defaults too: an installation may have ALTER DEFAULT
        -- PRIVILEGES grants that the existing overload deliberately revoked.
        FOR a IN SELECT acl.* FROM pg_proc p,
            LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) acl WHERE p.oid=target LOOP
            grantee_name := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM %s',target,grantee_name);
        END LOOP;
        FOR a IN SELECT * FROM aclexplode(COALESCE(f.proacl,acldefault('f',f.proowner))) LOOP
            grantee_name := CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END;
            EXECUTE format('GRANT %s ON FUNCTION %s TO %s%s',a.privilege_type,target,grantee_name,
                CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
        END LOOP;
    END LOOP;
END $$;
DROP FUNCTION signer.tx_permission_grant_on_address(character varying,character varying,numeric);
DROP FUNCTION signer.tx_permission_grant_on_object(character varying,character varying,character varying,numeric);
DROP FUNCTION signer.tx_permission_revoke_on_address(character varying,character varying,numeric);
DROP FUNCTION signer.tx_permission_revoke_on_object(character varying,character varying,character varying,numeric);
DROP FUNCTION signer.tx_permission_set_on_address(character varying,character varying,numeric);
DROP FUNCTION signer.tx_permission_set_on_object(character varying,character varying,character varying,numeric);
CREATE OR REPLACE FUNCTION signer.create_transaction_v022(_player_id character varying, _object_id character varying, _module structs.signer_tx_module, _command structs.signer_tx_type, _args jsonb, _flags jsonb, _checks jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
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
$function$
;
CREATE OR REPLACE FUNCTION signer.authorized_accounts_v022(_tx_id integer)
 RETURNS TABLE(account_id integer, address character varying, status structs.signer_account_status)
 LANGUAGE sql
 STABLE
AS $function$
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
$function$
;
DROP FUNCTION signer.PERMISSION_MUTATION_CHECK(character varying,text,character varying,character varying,text,integer);
ALTER TABLE signer.tx_authority
    DROP CONSTRAINT tx_authority_check_type_check,
    DROP CONSTRAINT tx_authority_permission_check,
    DROP CONSTRAINT tx_authority_subject_check,
    DROP CONSTRAINT tx_authority_pkey,
    DROP COLUMN subject_id,
    DROP COLUMN operation,
    ADD CONSTRAINT tx_authority_check_type_check CHECK (check_type IN ('object','object-owner','address-owner','provider-open')),
    ADD CONSTRAINT tx_authority_permission_check CHECK (permission BETWEEN 1 AND 33554431),
    ADD PRIMARY KEY(tx_id,check_type,object_id,permission);
COMMIT;
