-- Deploy structs-pg:function-signer-tx-20261030-registration to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'registration wrappers require the coordinated v022-1 signer contract';
    END IF;
END $$;

-- The chain reads the nonce itself; this is the context signed by the device,
-- not an invented nonce CLI flag or an indexed substitute for a live query.
CREATE TABLE signer.tx_registration_proof (
    tx_id INTEGER PRIMARY KEY REFERENCES signer.tx(id) ON DELETE CASCADE,
    signing_player_id CHARACTER VARYING NOT NULL CHECK (signing_player_id ~ '^1-[1-9][0-9]*$'),
    player_id CHARACTER VARYING NOT NULL CHECK (player_id ~ '^1-[1-9][0-9]*$'),
    address CHARACTER VARYING NOT NULL CHECK (address ~ '^structs1[ac-hj-np-z02-9]{38}$'),
    pubkey TEXT NOT NULL CHECK (pubkey ~ '^(02|03)[0-9a-f]{64}$'),
    signature TEXT NOT NULL CHECK (signature ~ '^[0-9a-f]{128}([0-9a-f]{2})?$'),
    permissions INTEGER NOT NULL CHECK (permissions BETWEEN 1 AND 33554431),
    chain_id TEXT NOT NULL CHECK (chain_id='structstestnet-111'),
    protocol TEXT NOT NULL CHECK (protocol='v0.22.0'),
    proof_nonce NUMERIC NOT NULL CHECK (proof_nonce BETWEEN 0 AND 18446744073709551615 AND proof_nonce=trunc(proof_nonce)),
    source_height BIGINT NOT NULL CHECK (source_height BETWEEN 3353000 AND 9007199254740991),
    message TEXT GENERATED ALWAYS AS ('CHAIN' || chain_id || '|REGISTERADDRESSPLAYER' || player_id
        || 'ADDRESS' || address || 'NONCE' || trunc(proof_nonce)::text) STORED
);
CREATE FUNCTION signer.REGISTRATION_PROOF_IMMUTABLE() RETURNS TRIGGER LANGUAGE plpgsql AS $BODY$
BEGIN
    RAISE EXCEPTION 'registration proof context is immutable' USING ERRCODE='55000';
END
$BODY$;
CREATE TRIGGER registration_proof_immutable BEFORE UPDATE ON signer.tx_registration_proof
    FOR EACH ROW EXECUTE FUNCTION signer.REGISTRATION_PROOF_IMMUTABLE();

ALTER TABLE signer.account ADD COLUMN registration_tx_id INTEGER
    REFERENCES signer.tx_registration_proof(tx_id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX signer_account_registration_tx_idx ON signer.account(registration_tx_id)
    WHERE registration_tx_id IS NOT NULL;

CREATE FUNCTION signer.REGISTRATION_CONTEXT(_player_id CHARACTER VARYING,_address CHARACTER VARYING,
    _pubkey CHARACTER VARYING,_signature CHARACTER VARYING,_permissions NUMERIC,_context JSONB)
RETURNS JSONB LANGUAGE plpgsql IMMUTABLE AS $BODY$
DECLARE _permission TEXT; _nonce TEXT; _height TEXT;
BEGIN
    _permission := signer.PERMISSION_ARGUMENT(_permissions);
    IF _player_id IS NULL OR _player_id !~ '^1-[1-9][0-9]*$'
        OR _address IS NULL OR _address !~ '^structs1[ac-hj-np-z02-9]{38}$'
        OR _pubkey IS NULL OR _pubkey !~* '^(02|03)[0-9a-f]{64}$'
        OR _signature IS NULL OR _signature !~* '^[0-9a-f]{128}([0-9a-f]{2})?$' THEN
        RAISE EXCEPTION 'invalid registration identity or proof encoding' USING ERRCODE='22023';
    END IF;
    PERFORM signer.UINT64_ARGUMENT(substring(_player_id from 3)::numeric,'registration player',FALSE);
    IF _context IS NULL OR jsonb_typeof(_context)<>'object' THEN
        RAISE EXCEPTION 'registration requires explicit proof context' USING ERRCODE='22023';
    END IF;
    IF NOT _context ?& ARRAY['chain_id','protocol','source_height','player_id','address',
            'proof_nonce','registered_player_id','timeout_height']
        OR (_context - ARRAY['chain_id','protocol','source_height','player_id','address',
            'proof_nonce','registered_player_id','timeout_height'])<>'{}'::jsonb
        OR EXISTS (SELECT 1 FROM jsonb_each(_context) c WHERE jsonb_typeof(c.value)<>'string')
        OR _context->>'chain_id'<>'structstestnet-111' OR _context->>'protocol'<>'v0.22.0'
        OR _context->>'player_id'<>_player_id OR _context->>'address'<>_address
        OR _context->>'registered_player_id'<>'' OR _context->>'timeout_height'<>'0' THEN
        RAISE EXCEPTION 'registration proof context does not match this request' USING ERRCODE='22023';
    END IF;
    _nonce := _context->>'proof_nonce'; _height := _context->>'source_height';
    IF _nonce !~ '^(0|[1-9][0-9]{0,19})$' OR _height !~ '^[1-9][0-9]{0,15}$' THEN
        RAISE EXCEPTION 'registration nonce and height must be exact integer strings' USING ERRCODE='22023';
    END IF;
    PERFORM signer.UINT64_ARGUMENT(_nonce::numeric,'registration nonce');
    IF _height::numeric NOT BETWEEN 3353000 AND 9007199254740991 THEN
        RAISE EXCEPTION 'registration proof is outside the v0.22 height range' USING ERRCODE='22023';
    END IF;
    RETURN _context || jsonb_build_object('pubkey',lower(_pubkey),'signature',lower(_signature),
        'permissions',_permission,'message','CHAIN' || (_context->>'chain_id') || '|REGISTERADDRESSPLAYER'
            || _player_id || 'ADDRESS' || _address || 'NONCE' || _nonce);
END
$BODY$;

CREATE FUNCTION signer.REGISTRATION_PROOF_V022(_tx_id INTEGER) RETURNS JSONB LANGUAGE sql STABLE AS $BODY$
    SELECT jsonb_build_object('chain_id',chain_id,'protocol',protocol,'source_height',source_height::text,
        'player_id',player_id,'address',address,'proof_nonce',trunc(proof_nonce)::text,
        'registered_player_id','','timeout_height','0','pubkey',pubkey,'signature',signature,
        'permissions',permissions::text,'message',message)
    FROM signer.tx_registration_proof WHERE tx_id=_tx_id;
$BODY$;

CREATE FUNCTION signer.REGISTRATION_CONTEXT_CHECK(_tx_id INTEGER) RETURNS BOOLEAN LANGUAGE sql STABLE AS $BODY$
    SELECT EXISTS (
        SELECT 1 FROM signer.tx t JOIN signer.tx_registration_proof p ON p.tx_id=t.id
        JOIN structs.player target ON target.id=p.player_id
        WHERE t.id=_tx_id AND t.contract='v022-1' AND t.module='structs' AND t.command='address-register'
            AND t.requested_player_id=p.signing_player_id AND t.chain_id=p.chain_id AND t.object_id=p.player_id
            AND t.args=jsonb_build_array(p.player_id,p.address,p.pubkey,p.signature,p.permissions::text)
            AND t.flags='{}'::jsonb
            AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
                AND rule.check_type='object' AND rule.object_id=p.player_id AND rule.permission=p.permissions
                AND rule.subject_id='' AND rule.operation='')
            AND NOT EXISTS (SELECT 1 FROM structs.player_address pa WHERE pa.address=p.address AND pa.status='approved')
            AND NOT EXISTS (SELECT 1 FROM structs.vault v WHERE v.address=p.address)
    );
$BODY$;

CREATE FUNCTION signer.ADDRESS_MANAGEMENT_CHECK(_tx_id INTEGER) RETURNS BOOLEAN LANGUAGE sql STABLE AS $BODY$
    SELECT EXISTS (
        SELECT 1 FROM signer.tx t JOIN structs.player_address pa ON pa.address=t.args->>0 AND pa.status='approved'
        JOIN structs.player p ON p.id=pa.player_id
        WHERE t.id=_tx_id AND t.module='structs' AND t.flags='{}'::jsonb
            AND t.args=jsonb_build_array(pa.address)
            AND pa.address ~ '^structs1[ac-hj-np-z02-9]{38}$'
            AND NOT EXISTS (SELECT 1 FROM structs.vault v WHERE v.address=pa.address)
            AND (t.command='player-update-primary-address'
                OR (t.command='address-revoke' AND pa.address IS DISTINCT FROM p.primary_address))
            AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
                AND rule.check_type='address-owner' AND rule.object_id=pa.address
                AND rule.permission=CASE WHEN t.command='address-revoke' THEN 8 ELSE 33554431 END
                AND rule.subject_id='' AND rule.operation='')
    );
$BODY$;

CREATE FUNCTION signer.CREATE_ADDRESS_REGISTRATION_V022(_signing_player_id CHARACTER VARYING,_player_id CHARACTER VARYING,
    _address CHARACTER VARYING,_pubkey CHARACTER VARYING,_signature CHARACTER VARYING,_permissions NUMERIC,_proof_context JSONB)
RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _proof JSONB; _tx JSONB;
BEGIN
    _proof := signer.REGISTRATION_CONTEXT(_player_id,_address,_pubkey,_signature,_permissions,_proof_context);
    IF NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_player_id)
        OR EXISTS (SELECT 1 FROM structs.player_address WHERE address=_address AND status='approved')
        OR EXISTS (SELECT 1 FROM structs.vault WHERE address=_address) THEN
        RAISE EXCEPTION 'registration target is absent or address already belongs to an owner' USING ERRCODE='22023';
    END IF;
    _tx := signer.CREATE_TRANSACTION_V022(_signing_player_id,_player_id,'structs','address-register',
        jsonb_build_array(_player_id,_address,_proof->>'pubkey',_proof->>'signature',_proof->>'permissions'),
        '{}'::jsonb,jsonb_build_array(jsonb_build_object('check_type','object','object_id',_player_id,'permission',_permissions::integer)));
    INSERT INTO signer.tx_registration_proof(tx_id,signing_player_id,player_id,address,pubkey,signature,permissions,
        chain_id,protocol,proof_nonce,source_height)
    VALUES((_tx->>'id')::integer,_signing_player_id,_player_id,_address,_proof->>'pubkey',_proof->>'signature',_permissions::integer,
        _proof->>'chain_id',_proof->>'protocol',(_proof->>'proof_nonce')::numeric,(_proof->>'source_height')::bigint);
    RETURN _tx;
END
$BODY$;
REVOKE ALL ON FUNCTION signer.CREATE_ADDRESS_REGISTRATION_V022(character varying,character varying,
    character varying,character varying,character varying,numeric,jsonb) FROM PUBLIC;

CREATE OR REPLACE FUNCTION signer.tx_address_register(_player_id CHARACTER VARYING,_address_to_register CHARACTER VARYING,
    _proof_pub_key CHARACTER VARYING,_proof_signature CHARACTER VARYING,_permissions INTEGER)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    RAISE EXCEPTION 'registration requires chain and nonce proof context; use the context overload' USING ERRCODE='22023';
END
$BODY$;

CREATE FUNCTION signer.tx_address_register(_player_id CHARACTER VARYING,_address_to_register CHARACTER VARYING,
    _proof_pub_key CHARACTER VARYING,_proof_signature CHARACTER VARYING,_permissions NUMERIC,_proof_context JSONB,
    _signing_player_id CHARACTER VARYING DEFAULT NULL)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    PERFORM signer.CREATE_ADDRESS_REGISTRATION_V022(COALESCE(_signing_player_id,_player_id),_player_id,_address_to_register,
        _proof_pub_key,_proof_signature,_permissions,_proof_context);
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.update_pending_account(_account_id INTEGER,_player_id CHARACTER VARYING,
    _address CHARACTER VARYING,_pubkey CHARACTER VARYING,_signature CHARACTER VARYING,_permission INTEGER)
RETURNS void LANGUAGE plpgsql VOLATILE AS $BODY$
BEGIN
    RAISE EXCEPTION 'managed registration requires chain and nonce proof context; use the context overload' USING ERRCODE='22023';
END
$BODY$;

CREATE FUNCTION signer.update_pending_account(_account_id INTEGER,_player_id CHARACTER VARYING,_address CHARACTER VARYING,
    _pubkey CHARACTER VARYING,_signature CHARACTER VARYING,_permission NUMERIC,_proof_context JSONB,
    _signing_player_id CHARACTER VARYING DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _account signer.account%ROWTYPE; _role signer.role%ROWTYPE; _proof JSONB; _tx JSONB;
BEGIN
    _proof := signer.REGISTRATION_CONTEXT(_player_id,_address,_pubkey,_signature,_permission,_proof_context);
    SELECT * INTO _account FROM signer.account WHERE id=_account_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'managed account does not exist' USING ERRCODE='22023'; END IF;
    SELECT * INTO _role FROM signer.role WHERE id=_account.role_id FOR SHARE;
    IF NOT FOUND OR _role.player_id IS DISTINCT FROM _player_id OR _role.status IS DISTINCT FROM 'ready'::structs.signer_role_status
        OR (_account.address IS NOT NULL AND _account.address<>_address) THEN
        RAISE EXCEPTION 'managed registration does not match its account and role' USING ERRCODE='22023';
    END IF;
    IF _account.registration_tx_id IS NOT NULL THEN
        SELECT to_jsonb(t) INTO _tx FROM signer.tx t WHERE t.id=_account.registration_tx_id;
        IF _proof IS DISTINCT FROM signer.REGISTRATION_PROOF_V022(_account.registration_tx_id)
            OR _tx->>'requested_player_id' IS DISTINCT FROM COALESCE(_signing_player_id,_player_id) THEN
            RAISE EXCEPTION 'managed account already has a different registration request' USING ERRCODE='55000';
        END IF;
        -- A restart never creates another submission or moves an active account
        -- back to pending. Confirmation belongs to the durable worker lifecycle.
        RETURN _tx;
    END IF;
    IF _account.status IS DISTINCT FROM 'generating'::structs.signer_account_status THEN
        RAISE EXCEPTION 'managed account is not awaiting generated-key registration' USING ERRCODE='55000';
    END IF;
    _tx := signer.CREATE_ADDRESS_REGISTRATION_V022(COALESCE(_signing_player_id,_player_id),_player_id,_address,
        _pubkey,_signature,_permission,_proof_context);
    UPDATE signer.account SET address=_address,status='pending',registration_tx_id=(_tx->>'id')::integer,updated_at=NOW()
    WHERE id=_account_id;
    RETURN _tx;
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_address_revoke(_player_id CHARACTER VARYING,_address_to_revoke CHARACTER VARYING)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_address_to_revoke AND pa.status='approved' AND pa.address IS DISTINCT FROM p.primary_address
            AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=pa.address)) THEN
        RAISE EXCEPTION 'revocation requires a current non-primary player address' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','address-revoke',
        jsonb_build_array(_address_to_revoke),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','address-owner','object_id',_address_to_revoke,'permission',8)));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.tx_player_update_primary_address(_player_id CHARACTER VARYING,_primary_address CHARACTER VARYING)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM structs.player_address pa JOIN structs.player p ON p.id=pa.player_id
        WHERE pa.address=_primary_address AND pa.status='approved'
            AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=pa.address)) THEN
        RAISE EXCEPTION 'primary address must already be registered to a player' USING ERRCODE='22023';
    END IF;
    PERFORM signer.CREATE_TRANSACTION_V022(_player_id,_player_id,'structs','player-update-primary-address',
        jsonb_build_array(_primary_address),'{}'::jsonb,
        jsonb_build_array(jsonb_build_object('check_type','address-owner','object_id',_primary_address,'permission',33554431)));
END
$BODY$;

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
      AND (t.command<>'address-register' OR signer.REGISTRATION_CONTEXT_CHECK(t.id))
      AND (t.command NOT IN ('address-revoke','player-update-primary-address') OR signer.ADDRESS_MANAGEMENT_CHECK(t.id))
      AND EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM signer.tx_authority rule WHERE rule.tx_id=t.id
          AND (CASE WHEN rule.check_type IN ('permission-address','permission-object') THEN
              signer.PERMISSION_MUTATION_CHECK(a.address,rule.check_type,rule.object_id,
                  rule.subject_id,rule.operation,rule.permission)
          ELSE signer.TRANSACTION_AUTHORITY_CHECK(a.address,t.requested_player_id,
              rule.check_type,rule.object_id,rule.permission) END) IS DISTINCT FROM TRUE);
$function$
;
DO $$
DECLARE f RECORD; a RECORD; target REGPROCEDURE; grantee_name TEXT;
BEGIN
    FOR f IN SELECT p.proowner,p.proacl,v.target
        FROM (VALUES
            ('signer.tx_address_register(character varying,character varying,character varying,character varying,integer)','signer.tx_address_register(character varying,character varying,character varying,character varying,numeric,jsonb,character varying)'),
            ('signer.update_pending_account(integer,character varying,character varying,character varying,character varying,integer)','signer.update_pending_account(integer,character varying,character varying,character varying,character varying,numeric,jsonb,character varying)')
        ) v(source,target) JOIN pg_proc p ON p.oid=v.source::regprocedure
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
