-- Disposable database only. Proofs here test SQL encoding/context binding;
-- cryptographic verification and live nonce queries belong to the worker.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
CREATE FUNCTION pg_temp.registration_context(_address TEXT,_nonce TEXT DEFAULT '0',_player TEXT DEFAULT '1-990940')
RETURNS JSONB LANGUAGE sql IMMUTABLE AS $$
    SELECT jsonb_build_object('chain_id','structstestnet-111','protocol','v0.22.0','source_height','3353000',
        'player_id',_player,'address',_address,'proof_nonce',_nonce,'registered_player_id','','timeout_height','0');
$$;
DO $$
DECLARE
    address_a TEXT := 'structs1' || repeat('q',38);
    address_b TEXT := 'structs1' || repeat('p',38);
    address_c TEXT := 'structs1' || repeat('r',38);
    pubkey TEXT := '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
    signature TEXT := repeat('ab',64);
    context JSONB; bad_context JSONB; bad NUMERIC; value TEXT;
    request signer.tx%ROWTYPE; managed JSONB; retried JSONB; before_count BIGINT;
BEGIN
    context := pg_temp.registration_context(address_a);
    PERFORM signer.tx_address_register('1-990940',address_a,upper(pubkey),upper(signature),16,context);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.requested_player_id<>'1-990940' OR request.object_id<>'1-990940'
        OR request.args<>jsonb_build_array('1-990940',address_a,pubkey,signature,'16') OR request.flags<>'{}'
        OR request.permission_requirement<>16 OR NOT signer.REGISTRATION_CONTEXT_CHECK(request.id)
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuerestricted') THEN
        RAISE EXCEPTION 'registration lost player positional arg, actor or requested permission selection';
    END IF;
    IF signer.REGISTRATION_PROOF_V022(request.id)<>context || jsonb_build_object('pubkey',pubkey,'signature',signature,
        'permissions','16','message','CHAINstructstestnet-111|REGISTERADDRESSPLAYER1-990940ADDRESS' || address_a || 'NONCE0') THEN
        RAISE EXCEPTION 'registration context or exact nonce zero was not preserved';
    END IF;
    UPDATE signer.tx SET args=jsonb_set(args,'{4}','"32"') WHERE id=request.id;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'proof record did not bind queued grant arguments';
    END IF;
    UPDATE signer.tx SET args=request.args WHERE id=request.id;
    UPDATE signer.tx_authority SET permission=1 WHERE tx_id=request.id;
    IF signer.REGISTRATION_CONTEXT_CHECK(request.id) THEN RAISE EXCEPTION 'proof ignored a weakened authority rule'; END IF;
    UPDATE signer.tx_authority SET permission=16 WHERE tx_id=request.id;
    UPDATE signer.tx SET requested_player_id='1-990941' WHERE id=request.id;
    IF signer.REGISTRATION_CONTEXT_CHECK(request.id) THEN RAISE EXCEPTION 'proof lost the selected acting player'; END IF;
    UPDATE signer.tx SET requested_player_id='1-990940' WHERE id=request.id;
    BEGIN
        UPDATE signer.tx_registration_proof SET proof_nonce=1 WHERE tx_id=request.id;
        RAISE EXCEPTION 'stored proof nonce was rewritten';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
    INSERT INTO structs.player_address(address,player_id,status) VALUES(address_a,'1-990941','approved');
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'already registered address was claimed';
    END IF;
    UPDATE structs.player_address SET status='revoked' WHERE address=address_a;
    IF NOT signer.REGISTRATION_CONTEXT_CHECK(request.id) THEN RAISE EXCEPTION 'revoked address could not reach live nonce verification'; END IF;
    -- The indexed revocation cannot prove nonce zero is reusable. The exact
    -- stored nonce must still be checked against the node before submission.
    PERFORM signer.tx_address_register('1-990940',address_a,pubkey,signature,16,pg_temp.registration_context(address_a,'18446744073709551615'));
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF signer.REGISTRATION_PROOF_V022(request.id)->>'proof_nonce'<>'18446744073709551615'
        OR signer.REGISTRATION_PROOF_V022(request.id)->>'message'<>
            'CHAINstructstestnet-111|REGISTERADDRESSPLAYER1-990940ADDRESS' || address_a || 'NONCE18446744073709551615' THEN
        RAISE EXCEPTION 'max uint64 nonce changed in storage or message rendering';
    END IF;

    -- A different actor must be named, and must hold the requested bits on the
    -- proof's target player. Being that target's guild owner is insufficient.
    PERFORM signer.tx_address_register('1-990940',address_a,pubkey,signature,16,context,'1-990941');
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.requested_player_id<>'1-990941' OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'registration substituted target identity for an unauthorized actor';
    END IF;
    INSERT INTO structs.permission(id,object_id,player_id,val)
    VALUES('1-990940@1-990941','1-990940','1-990941',16);
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeyb') THEN
        RAISE EXCEPTION 'authorized registration actor was not recognized';
    END IF;

    FOREACH bad_context IN ARRAY ARRAY[
        NULL,'{}',context-'proof_nonce',jsonb_set(context,'{proof_nonce}','null'),
        jsonb_set(context,'{proof_nonce}','0'),jsonb_set(context,'{proof_nonce}','"00"'),
        jsonb_set(context,'{proof_nonce}','"18446744073709551616"'),
        jsonb_set(context,'{chain_id}','"different-chain"'),jsonb_set(context,'{protocol}','"v0.21.0"'),
        jsonb_set(context,'{source_height}','"3352999"'),jsonb_set(context,'{source_height}','"9007199254740992"'),
        jsonb_set(context,'{registered_player_id}','"1-990941"'),jsonb_set(context,'{timeout_height}','"3352999"'),
        jsonb_set(context,'{player_id}','"1-990941"'),jsonb_set(context,'{address}','"other-address"'),context || '{"extra": "field"}'
    ]::JSONB[] LOOP
        BEGIN
            PERFORM signer.tx_address_register('1-990940',address_a,pubkey,signature,16,bad_context);
            RAISE EXCEPTION 'invalid or ambiguous proof context accepted: %',bad_context;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    FOREACH bad IN ARRAY ARRAY[NULL,-1,0,1.1,33554432,'NaN','Infinity']::NUMERIC[] LOOP
        BEGIN
            PERFORM signer.tx_address_register('1-990940',address_a,pubkey,signature,bad,context);
            RAISE EXCEPTION 'invalid registration mask accepted: %',bad;
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    FOREACH value IN ARRAY ARRAY[NULL,'','zz','04' || repeat('ab',64)] LOOP
        BEGIN
            PERFORM signer.tx_address_register('1-990940',address_a,value,signature,16,context);
            RAISE EXCEPTION 'invalid pubkey encoding accepted';
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    FOREACH value IN ARRAY ARRAY[NULL,'','zz',repeat('ab',63),repeat('ab',66)] LOOP
        BEGIN
            PERFORM signer.tx_address_register('1-990940',address_a,pubkey,value,16,context);
            RAISE EXCEPTION 'invalid signature encoding accepted';
        EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    END LOOP;
    PERFORM signer.tx_address_register('1-990940',address_a,pubkey,signature || '01',16,context);
    BEGIN
        PERFORM signer.tx_address_register('1-990940',address_a,pubkey,signature,16);
        RAISE EXCEPTION 'legacy context-free registration accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

    INSERT INTO signer.account(id,role_id,status) VALUES(990943,990940,'generating');
    context := pg_temp.registration_context(address_b,'9');
    SELECT count(*) INTO before_count FROM signer.tx;
    managed := signer.UPDATE_PENDING_ACCOUNT(990943,'1-990940',address_b,pubkey,signature,16,context);
    IF (SELECT address IS DISTINCT FROM address_b OR status IS DISTINCT FROM 'pending'::structs.signer_account_status
        OR registration_tx_id IS DISTINCT FROM (managed->>'id')::integer
        FROM signer.account WHERE id=990943) OR (SELECT count(*) FROM signer.tx)<>before_count+1 THEN
        RAISE EXCEPTION 'managed registration did not atomically link the account and request';
    END IF;
    retried := signer.UPDATE_PENDING_ACCOUNT(990943,'1-990940',address_b,pubkey,signature,16,context);
    IF retried->>'id'<>managed->>'id' OR (SELECT count(*) FROM signer.tx)<>before_count+1 THEN
        RAISE EXCEPTION 'managed restart generated a replacement transaction';
    END IF;
    UPDATE signer.account SET status='available' WHERE id=990943;
    PERFORM signer.UPDATE_PENDING_ACCOUNT(990943,'1-990940',address_b,pubkey,signature,16,context);
    IF (SELECT status FROM signer.account WHERE id=990943)<>'available' THEN
        RAISE EXCEPTION 'managed restart regressed an active account to pending';
    END IF;
    BEGIN
        PERFORM signer.UPDATE_PENDING_ACCOUNT(990943,'1-990940',address_b,pubkey,signature,32,context);
        RAISE EXCEPTION 'managed request changed its grant after queueing';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
    BEGIN
        DELETE FROM signer.tx WHERE id=(managed->>'id')::integer;
        RAISE EXCEPTION 'managed account lost its linked registration proof';
    EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN NULL; END;
    INSERT INTO signer.account(id,role_id,status) VALUES(990944,990941,'generating'),(990945,990940,'stub');
    BEGIN
        PERFORM signer.UPDATE_PENDING_ACCOUNT(990944,'1-990940',address_c,pubkey,signature,16,pg_temp.registration_context(address_c));
        RAISE EXCEPTION 'managed account was attached to another player';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.UPDATE_PENDING_ACCOUNT(990945,'1-990940',address_c,pubkey,signature,16,pg_temp.registration_context(address_c));
        RAISE EXCEPTION 'stub skipped key-generation claim';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
    BEGIN
        PERFORM signer.UPDATE_PENDING_ACCOUNT(990944,'1-990941',address_c,pubkey,signature,16);
        RAISE EXCEPTION 'managed legacy helper queued a context-free proof';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    IF (SELECT address IS NOT NULL OR status<>'generating' FROM signer.account WHERE id=990944) THEN
        RAISE EXCEPTION 'rejected managed request changed account state';
    END IF;

    -- Device management resolves the named subject independently of the actor.
    INSERT INTO structs.player_address(address,player_id,status) VALUES(address_c,'1-990940','approved');
    UPDATE structs.permission SET val=2 WHERE id='8-queuekeya@0';
    PERFORM signer.tx_address_revoke('1-990940',address_c);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>jsonb_build_array(address_c) OR request.permission_requirement<>8
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'address revoke used Admin instead of Delete';
    END IF;
    UPDATE structs.permission SET val=8 WHERE id='8-queuekeya@0';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'delete-only actor could not revoke a secondary address';
    END IF;
    UPDATE structs.player SET primary_address=address_c WHERE id='1-990940';
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'revocation ignored a later primary rotation';
    END IF;
    BEGIN
        PERFORM signer.tx_address_revoke('1-990940',address_c);
        RAISE EXCEPTION 'primary address revocation queued';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    UPDATE structs.player SET primary_address='queuekeya' WHERE id='1-990940';
    PERFORM signer.tx_player_update_primary_address('1-990940',address_c);
    SELECT * INTO request FROM signer.tx ORDER BY id DESC LIMIT 1;
    IF request.args<>jsonb_build_array(address_c) OR request.permission_requirement<>33554431
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'primary rotation bypassed the full-access key ceiling';
    END IF;
    UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';
    IF NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id) WHERE address='queuekeya') THEN
        RAISE EXCEPTION 'full-access actor could not rotate the primary';
    END IF;
    UPDATE structs.player_address SET status='revoked' WHERE address=address_c;
    IF EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(request.id)) THEN
        RAISE EXCEPTION 'primary rotation ignored revoked membership';
    END IF;
    INSERT INTO structs.vault(owner_id,address,account_number) VALUES('1-990940',address_c,0);
    BEGIN
        PERFORM signer.tx_address_register('1-990940',address_c,pubkey,signature,16,pg_temp.registration_context(address_c));
        RAISE EXCEPTION 'vault registration queued';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
        PERFORM signer.tx_player_update_primary_address('1-990940',address_c);
        RAISE EXCEPTION 'vault primary rotation queued';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;

-- The worker can prepare and claim with explicit table/function grants, without
-- granting it superuser or permitting the proof-less legacy helper to write.
UPDATE signer.account SET registration_tx_id=NULL WHERE registration_tx_id IS NOT NULL;
DELETE FROM signer.tx;
INSERT INTO signer.account(id,role_id,status) VALUES(990946,990940,'generating');
CREATE ROLE v022_registration_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_registration_caller;
GRANT SELECT ON signer.role,structs.player,structs.player_address,structs.permission,
    structs.permission_guild_rank,structs.vault,structs.guild TO v022_registration_caller;
GRANT UPDATE (id) ON signer.role TO v022_registration_caller;
GRANT SELECT,INSERT,UPDATE ON signer.tx TO v022_registration_caller;
GRANT SELECT,UPDATE ON signer.account TO v022_registration_caller;
GRANT SELECT,INSERT ON signer.tx_authority,signer.tx_registration_proof TO v022_registration_caller;
GRANT USAGE ON SEQUENCE signer.tx_id_seq TO v022_registration_caller;
GRANT EXECUTE ON FUNCTION signer.CLAIM_TRANSACTION_V022(),structs.api_readiness(TEXT[]),
    signer.CREATE_TRANSACTION_V022(character varying,character varying,structs.signer_tx_module,structs.signer_tx_type,jsonb,jsonb,jsonb),
    signer.CREATE_ADDRESS_REGISTRATION_V022(character varying,character varying,character varying,character varying,character varying,numeric,jsonb)
TO v022_registration_caller;
SET LOCAL ROLE v022_registration_caller;
DO $$
DECLARE address TEXT := 'structs1' || repeat('s',38); request JSONB; claimed JSONB;
BEGIN
    request := signer.UPDATE_PENDING_ACCOUNT(990946,'1-990940',address,'02' || repeat('ab',32),repeat('cd',64),16,
        pg_temp.registration_context(address));
    claimed := signer.CLAIM_TRANSACTION_V022();
    IF claimed IS NULL OR claimed->'transaction'->>'id'<>request->>'id'
        OR claimed->'account'->>'address'<>'queuerestricted'
        OR signer.REGISTRATION_PROOF_V022((request->>'id')::integer)->>'proof_nonce'<>'0' THEN
        RAISE EXCEPTION 'scoped registration worker failed to prepare, claim or read proof context';
    END IF;
END $$;
RESET ROLE;
ROLLBACK;
