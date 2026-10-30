-- Deploy structs-pg:function-signer-tx-20261030-permission-mutation to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'permission wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

-- A replacement's old grant is live state, not an enqueue-time permission
-- mask. Keep its subject and operation so a later claim can re-read that row.
ALTER TABLE signer.tx_authority
    ADD COLUMN subject_id CHARACTER VARYING NOT NULL DEFAULT '',
    ADD COLUMN operation TEXT NOT NULL DEFAULT '',
    DROP CONSTRAINT tx_authority_check_type_check,
    DROP CONSTRAINT tx_authority_permission_check,
    DROP CONSTRAINT tx_authority_pkey,
    ADD CONSTRAINT tx_authority_check_type_check CHECK (check_type IN
        ('object','object-owner','address-owner','provider-open','permission-address','permission-object')),
    ADD CONSTRAINT tx_authority_permission_check CHECK (permission BETWEEN 0 AND 33554431),
    ADD CONSTRAINT tx_authority_subject_check CHECK (
        (check_type IN ('object','object-owner','address-owner','provider-open')
            AND subject_id='' AND operation='' AND permission>0)
        OR (check_type IN ('permission-address','permission-object')
            AND operation IN ('grant','set','revoke') AND (operation='set' OR permission>0)
            AND ((check_type='permission-address' AND subject_id='')
                OR (check_type='permission-object' AND subject_id ~ '^1-[1-9][0-9]*$')))
    ),
    ADD PRIMARY KEY(tx_id,check_type,object_id,permission,subject_id,operation);

CREATE FUNCTION signer.PERMISSION_MUTATION_CHECK(_address CHARACTER VARYING,_check_type TEXT,
    _object_id CHARACTER VARYING,_subject_id CHARACTER VARYING,_operation TEXT,_permission INTEGER)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $BODY$
DECLARE
    _owner CHARACTER VARYING;
    _primary CHARACTER VARYING;
    _grant_id CHARACTER VARYING;
    _current INTEGER;
    _required INTEGER;
    _resulting INTEGER;
BEGIN
    IF _operation IS NULL OR _operation NOT IN ('grant','set','revoke')
        OR _permission IS NULL OR _permission NOT BETWEEN 0 AND 33554431
        OR (_operation<>'set' AND _permission=0) THEN RETURN FALSE; END IF;
    IF _check_type='permission-address' THEN
        IF _subject_id IS DISTINCT FROM '' THEN RETURN FALSE; END IF;
        SELECT p.id,p.primary_address INTO _owner,_primary
        FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_object_id AND pa.status='approved'
            AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=pa.address);
        IF _owner IS NULL THEN RETURN FALSE; END IF;
        _grant_id := '8-' || _object_id || '@0';
    ELSIF _check_type='permission-object' THEN
        IF NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_subject_id)
            OR signer.PERMISSION_CHECK(_address,_object_id,2) IS DISTINCT FROM TRUE THEN RETURN FALSE; END IF;
        _owner := _object_id;
        _grant_id := _object_id || '@' || _subject_id;
    ELSE
        RETURN FALSE;
    END IF;
    SELECT val INTO _current FROM structs.permission WHERE id=_grant_id;
    IF NOT FOUND THEN
        _current := 0;
    ELSIF _current IS NULL OR _current NOT BETWEEN 0 AND 33554431 THEN
        RETURN FALSE;
    END IF;
    _required := CASE WHEN _operation='set' THEN _permission | _current ELSE _permission END;
    _resulting := CASE _operation WHEN 'set' THEN _permission
        WHEN 'revoke' THEN _current & ~_permission ELSE _current | _permission END;
    IF _check_type='permission-address' AND _operation IN ('set','revoke')
        AND _object_id=_primary AND _resulting<>33554431 THEN RETURN FALSE; END IF;
    -- A zero replacement is valid only if it actually checks the existing
    -- nonzero grant. The chain deliberately rejects PermissionCheck(0).
    RETURN signer.PERMISSION_CHECK(_address,_owner,_required);
END
$BODY$;

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
            OR CASE WHEN c->>'check_type' IN ('permission-address','permission-object') THEN
                NOT c ?& ARRAY['subject_id','operation']
                OR jsonb_typeof(c->'subject_id')<>'string' OR jsonb_typeof(c->'operation')<>'string'
                OR (c - ARRAY['check_type','object_id','permission','subject_id','operation']) <> '{}'::jsonb
            ELSE (c - ARRAY['check_type','object_id','permission']) <> '{}'::jsonb END
            OR jsonb_typeof(c->'check_type')<>'string' OR jsonb_typeof(c->'object_id')<>'string'
            OR jsonb_typeof(c->'permission')<>'number'
            OR (c->>'permission') !~ '^(0|[1-9][0-9]{0,7})$'
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
    INSERT INTO signer.tx_authority(tx_id,check_type,object_id,permission,subject_id,operation)
    SELECT _tx.id,c->>'check_type',c->>'object_id',(c->>'permission')::int,
        COALESCE(c->>'subject_id',''),COALESCE(c->>'operation','')
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
          AND (CASE WHEN rule.check_type IN ('permission-address','permission-object') THEN
              signer.PERMISSION_MUTATION_CHECK(a.address,rule.check_type,rule.object_id,
                  rule.subject_id,rule.operation,rule.permission)
          ELSE signer.TRANSACTION_AUTHORITY_CHECK(a.address,t.requested_player_id,
              rule.check_type,rule.object_id,rule.permission) END) IS DISTINCT FROM TRUE);
$function$
;

CREATE TEMP TABLE signer_permission_function_acl ON COMMIT DROP AS
    SELECT p.proowner,p.proacl,v.source,v.target
    FROM (VALUES
            ('signer.tx_permission_grant_on_address(character varying,character varying,integer)','signer.tx_permission_grant_on_address(character varying,character varying,numeric)'),
            ('signer.tx_permission_grant_on_object(character varying,character varying,character varying,integer)','signer.tx_permission_grant_on_object(character varying,character varying,character varying,numeric)'),
            ('signer.tx_permission_revoke_on_address(character varying,character varying,integer)','signer.tx_permission_revoke_on_address(character varying,character varying,numeric)'),
            ('signer.tx_permission_revoke_on_object(character varying,character varying,character varying,integer)','signer.tx_permission_revoke_on_object(character varying,character varying,character varying,numeric)'),
            ('signer.tx_permission_set_on_address(character varying,character varying,integer)','signer.tx_permission_set_on_address(character varying,character varying,numeric)'),
            ('signer.tx_permission_set_on_object(character varying,character varying,character varying,integer)','signer.tx_permission_set_on_object(character varying,character varying,character varying,numeric)')
    ) v(source,target) JOIN pg_proc p ON p.oid=v.source::regprocedure;
DROP FUNCTION signer.tx_permission_grant_on_address(character varying,character varying,integer);
DROP FUNCTION signer.tx_permission_grant_on_object(character varying,character varying,character varying,integer);
DROP FUNCTION signer.tx_permission_revoke_on_address(character varying,character varying,integer);
DROP FUNCTION signer.tx_permission_revoke_on_object(character varying,character varying,character varying,integer);
DROP FUNCTION signer.tx_permission_set_on_address(character varying,character varying,integer);
DROP FUNCTION signer.tx_permission_set_on_object(character varying,character varying,character varying,integer);

CREATE OR REPLACE FUNCTION signer.tx_permission_grant_on_address(_player_id character varying, _address character varying, _permissions numeric) RETURNS void AS $BODY$
DECLARE _argument TEXT;
BEGIN
    _argument := signer.PERMISSION_ARGUMENT(_permissions,FALSE);
    IF NOT EXISTS (SELECT 1 FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_address AND pa.status='approved'
            AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=pa.address)) THEN
        RAISE EXCEPTION 'permission address is not a current player signing address' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_address,'structs','permission-grant-on-address',
        jsonb_build_array(_address,_argument),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','permission-address','object_id',_address,
            'subject_id','','operation','grant','permission',_permissions::integer)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_grant_on_object(_player_id character varying, _object_id character varying, _target_player_id character varying, _permissions numeric) RETURNS void AS $BODY$
DECLARE _argument TEXT;
BEGIN
    _argument := signer.PERMISSION_ARGUMENT(_permissions,FALSE);
    IF signer.PERMISSION_OBJECT_OWNER(_object_id) IS NULL
        OR NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_target_player_id) THEN
        RAISE EXCEPTION 'permission object or target player does not exist' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_object_id,'structs','permission-grant-on-object',
        jsonb_build_array(_object_id,_target_player_id,_argument),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','permission-object','object_id',_object_id,
            'subject_id',_target_player_id,'operation','grant','permission',_permissions::integer)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_revoke_on_address(_player_id character varying, _address character varying, _permissions numeric) RETURNS void AS $BODY$
DECLARE _argument TEXT;
BEGIN
    _argument := signer.PERMISSION_ARGUMENT(_permissions,FALSE);
    IF NOT EXISTS (SELECT 1 FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_address AND pa.status='approved'
            AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=pa.address)) THEN
        RAISE EXCEPTION 'permission address is not a current player signing address' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_address,'structs','permission-revoke-on-address',
        jsonb_build_array(_address,_argument),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','permission-address','object_id',_address,
            'subject_id','','operation','revoke','permission',_permissions::integer)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_revoke_on_object(_player_id character varying, _object_id character varying, _target_player_id character varying, _permissions numeric) RETURNS void AS $BODY$
DECLARE _argument TEXT;
BEGIN
    _argument := signer.PERMISSION_ARGUMENT(_permissions,FALSE);
    IF signer.PERMISSION_OBJECT_OWNER(_object_id) IS NULL
        OR NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_target_player_id) THEN
        RAISE EXCEPTION 'permission object or target player does not exist' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_object_id,'structs','permission-revoke-on-object',
        jsonb_build_array(_object_id,_target_player_id,_argument),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','permission-object','object_id',_object_id,
            'subject_id',_target_player_id,'operation','revoke','permission',_permissions::integer)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_set_on_address(_player_id character varying, _address character varying, _permissions numeric) RETURNS void AS $BODY$
DECLARE _argument TEXT;
BEGIN
    _argument := signer.PERMISSION_ARGUMENT(_permissions,TRUE);
    IF NOT EXISTS (SELECT 1 FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_address AND pa.status='approved'
            AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=pa.address)) THEN
        RAISE EXCEPTION 'permission address is not a current player signing address' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_address,'structs','permission-set-on-address',
        jsonb_build_array(_address,_argument),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','permission-address','object_id',_address,
            'subject_id','','operation','set','permission',_permissions::integer)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

CREATE OR REPLACE FUNCTION signer.tx_permission_set_on_object(_player_id character varying, _object_id character varying, _target_player_id character varying, _permissions numeric) RETURNS void AS $BODY$
DECLARE _argument TEXT;
BEGIN
    _argument := signer.PERMISSION_ARGUMENT(_permissions,TRUE);
    IF signer.PERMISSION_OBJECT_OWNER(_object_id) IS NULL
        OR NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_target_player_id) THEN
        RAISE EXCEPTION 'permission object or target player does not exist' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_object_id,'structs','permission-set-on-object',
        jsonb_build_array(_object_id,_target_player_id,_argument),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','permission-object','object_id',_object_id,
            'subject_id',_target_player_id,'operation','set','permission',_permissions::integer)));
END
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT saved.proowner,saved.proacl,saved.target FROM pg_temp.signer_permission_function_acl saved
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
COMMIT;
