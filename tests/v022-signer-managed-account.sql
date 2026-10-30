-- Disposable database only. Opaque signatures/bytes exercise the SQL lifecycle;
-- the worker separately verifies real proofs, TxRaw and same-chain RPC results.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
CREATE FUNCTION pg_temp.managed_context(_address TEXT,_nonce TEXT DEFAULT '9',_height TEXT DEFAULT '3353000')
RETURNS JSONB LANGUAGE sql IMMUTABLE AS $$
    SELECT jsonb_build_object('chain_id','structstestnet-111','protocol','v0.22.0','source_height',_height,
        'player_id','1-990940','address',_address,'proof_nonce',_nonce,'registered_player_id','','timeout_height','0');
$$;
CREATE FUNCTION pg_temp.managed_refuses(statement TEXT,expected_state TEXT DEFAULT '55000') RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN EXECUTE statement;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE=expected_state THEN RETURN; END IF;
        RAISE;
    END;
    RAISE EXCEPTION 'statement unexpectedly succeeded: %',statement;
END $$;
SAVEPOINT managed_cases;

DO $$
#variable_conflict use_variable
DECLARE
    address TEXT := 'structs1' || repeat('q',38); pubkey TEXT := '02' || repeat('ab',32);
    signature TEXT := repeat('cd',64); context JSONB; request JSONB; claim JSONB; saved JSONB; outcome JSONB;
    first_id INTEGER; tx_id INTEGER; next_id INTEGER; token UUID; renewal TEXT; activation TEXT; value TEXT;
BEGIN
    INSERT INTO signer.account(id,role_id,status) VALUES(990950,990940,'generating');
    context := pg_temp.managed_context(address);
    request := signer.UPDATE_PENDING_ACCOUNT(990950,'1-990940',address,pubkey,signature,16,context);
    first_id := (request->>'id')::int; tx_id := first_id;
    activation := format('SELECT signer.ACTIVATE_ACCOUNT_V022(990950,%s)',tx_id);
    renewal := format('SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,%s,%L,%L::jsonb)',tx_id,signature,context);
    IF NOT EXISTS (SELECT 1 FROM signer.account_registration h WHERE h.tx_id=tx_id AND h.account_id=990950 AND h.previous_tx_id IS NULL) THEN
        RAISE EXCEPTION 'initial registration was not retained';
    END IF;
    PERFORM pg_temp.managed_refuses(activation);
    FOREACH value IN ARRAY ARRAY['available','signing','generating','stub',NULL] LOOP
        PERFORM pg_temp.managed_refuses(format('UPDATE signer.account SET status=%L WHERE id=990950',value));
    END LOOP;
    PERFORM pg_temp.managed_refuses('UPDATE signer.account SET registration_tx_id=NULL WHERE id=990950');
    PERFORM pg_temp.managed_refuses('UPDATE signer.account SET role_id=990941 WHERE id=990950');
    PERFORM pg_temp.managed_refuses('UPDATE signer.account SET address=''changed'' WHERE id=990950');
    PERFORM pg_temp.managed_refuses(renewal);
    -- A legacy error string is not a durable unsent decision.
    UPDATE signer.tx SET status='error' WHERE id=first_id;
    PERFORM pg_temp.managed_refuses(renewal);
    UPDATE signer.tx SET status='pending' WHERE id=first_id;
    claim := signer.CLAIM_TRANSACTION_V022(); token := (claim->'transaction'->>'claim_token')::uuid;
    IF (claim->'transaction'->>'id')::int<>tx_id THEN RAISE EXCEPTION 'wrong managed claim'; END IF;
    PERFORM pg_temp.managed_refuses(renewal);
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(tx_id,token,'proof changed before signing');
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(tx_id,token,'proof changed before signing');
    IF NOT signer.REGISTRATION_FAILED_V022(tx_id)
        OR NOT EXISTS (SELECT 1 FROM signer.tx_unsent_abort a WHERE a.tx_id=first_id AND a.claim_token=token) THEN
        RAISE EXCEPTION 'unsigned failure lost durable claim evidence';
    END IF;
    PERFORM pg_temp.managed_refuses(format('UPDATE signer.tx SET status=''pending'' WHERE id=%s',tx_id));
    PERFORM pg_temp.managed_refuses(format('UPDATE signer.tx_authority SET permission=32 WHERE tx_id=%s',tx_id));
    PERFORM pg_temp.managed_refuses(format('DELETE FROM signer.tx_unsent_abort WHERE tx_id=%s',tx_id));
    PERFORM pg_temp.managed_refuses(format('SELECT signer.ABORT_UNSENT_TRANSACTION_V022(%s,%L,''different reason'')',tx_id,token));
    PERFORM pg_temp.managed_refuses(format('SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,%s,%L,%L::jsonb)',
        tx_id,signature,pg_temp.managed_context(address,'8')));
    context := pg_temp.managed_context(address,'10','3353001');
    request := signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,tx_id,signature,context);
    next_id := (request->>'id')::int;
    IF next_id=tx_id OR (signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,tx_id,signature,context)->>'id')::int<>next_id
        OR (SELECT count(*) FROM signer.account_registration WHERE account_id=990950)<>2 THEN
        RAISE EXCEPTION 'renewal lost history or exact retry created another request';
    END IF;
    PERFORM pg_temp.managed_refuses(format('SELECT signer.ACTIVATE_ACCOUNT_V022(990950,%s)',tx_id));
    PERFORM pg_temp.managed_refuses(format('DELETE FROM signer.tx_registration_proof WHERE tx_id=%s',tx_id),'23001');
    PERFORM pg_temp.managed_refuses('DELETE FROM signer.account_registration WHERE account_id=990950');
    PERFORM pg_temp.managed_refuses('UPDATE signer.account_registration SET previous_tx_id=NULL WHERE account_id=990950');
    PERFORM pg_temp.managed_refuses(format('SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,%s,%L,%L::jsonb)',
        tx_id,repeat('ef',64),context));
    tx_id := next_id;

    -- Prepared bytes must be explicitly cancelled. A send marker, unknown
    -- transport or CheckTx acceptance never permits replacement or activation.
    claim := signer.CLAIM_TRANSACTION_V022(); token := (claim->'transaction'->>'claim_token')::uuid;
    PERFORM pg_temp.managed_refuses(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,''future-proof''::bytea,0,0,3353000,0)',tx_id,token));
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,convert_to('managed-prepared','UTF8'),0,0,3353001,0);
    renewal := format('SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,%s,%L,%L::jsonb)',tx_id,signature,context);
    PERFORM pg_temp.managed_refuses(renewal);
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(tx_id,token,'prepared proof expired');
    request := signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,tx_id,signature,context);
    tx_id := (request->>'id')::int;
    claim := signer.CLAIM_TRANSACTION_V022(); token := (claim->'transaction'->>'claim_token')::uuid;
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,convert_to('managed-unknown','UTF8'),0,0,3353001,0);
    PERFORM signer.BEGIN_SUBMISSION_V022(tx_id,token);
    renewal := format('SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,%s,%L,%L::jsonb)',tx_id,signature,context);
    activation := format('SELECT signer.ACTIVATE_ACCOUNT_V022(990950,%s)',tx_id);
    PERFORM pg_temp.managed_refuses(renewal);
    PERFORM signer.MARK_SUBMISSION_UNKNOWN_V022(tx_id,token,'transport lost');
    PERFORM pg_temp.managed_refuses(renewal);
    outcome := jsonb_build_object('stage','check_tx','hash',saved->>'tx_hash','code','0','codespace','','log','');
    PERFORM signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,outcome);
    PERFORM pg_temp.managed_refuses(renewal);
    PERFORM pg_temp.managed_refuses(activation);
    outcome := outcome || jsonb_build_object('stage','deliver_tx','code','5','height','3353002','index','0','block_hash',repeat('B',64));
    PERFORM signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,outcome);
    PERFORM pg_temp.managed_refuses(activation);
    PERFORM pg_temp.managed_refuses(renewal); -- Context predates the failed inclusion.
    context := pg_temp.managed_context(address,'10','3353002');
    request := signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,tx_id,signature,context);
    tx_id := (request->>'id')::int;

    -- A definitive CheckTx refusal also releases this registration for a fresh
    -- proof, while preserving the rejected signed identity.
    claim := signer.CLAIM_TRANSACTION_V022(); token := (claim->'transaction'->>'claim_token')::uuid;
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,convert_to('managed-rejected','UTF8'),0,0,3353002,0);
    PERFORM signer.BEGIN_SUBMISSION_V022(tx_id,token);
    PERFORM signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,jsonb_build_object(
        'stage','check_tx','hash',saved->>'tx_hash','code','5','codespace','sdk','log','refused'));
    request := signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,tx_id,signature,context);
    tx_id := (request->>'id')::int;
    claim := signer.CLAIM_TRANSACTION_V022(); token := (claim->'transaction'->>'claim_token')::uuid;
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,convert_to('managed-success','UTF8'),0,0,3353002,0);
    PERFORM signer.BEGIN_SUBMISSION_V022(tx_id,token);

    -- Matching arbitrary index rows are not evidence of this transaction's
    -- success, even after CheckTx. The registered key must remain pending.
    INSERT INTO structs.player_address(address,player_id,status) VALUES(address,'1-990940','approved');
    INSERT INTO structs.permission(id,val) VALUES('8-' || address || '@0',16);
    activation := format('SELECT signer.ACTIVATE_ACCOUNT_V022(990950,%s)',tx_id);
    PERFORM pg_temp.managed_refuses(activation);
    outcome := jsonb_build_object('stage','deliver_tx','hash',saved->>'tx_hash','code','0','codespace','','log','',
        'height','3353003','index','0','block_hash',repeat('C',64));
    PERFORM signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,outcome);
    PERFORM pg_temp.managed_refuses(activation); -- Index is behind inclusion.
    UPDATE sync_state.sync_cursor SET last_height=3353003,tip_height=3353003;
    UPDATE structs.current_block SET height=3353003,tip_height=3353003;
    UPDATE structs.api_refresh_state SET source_height=3353003;
    UPDATE structs.player_address SET player_id='1-990941' WHERE player_address.address=address;
    PERFORM pg_temp.managed_refuses(activation);
    UPDATE structs.player_address SET player_id='1-990940',status='revoked' WHERE player_address.address=address;
    PERFORM pg_temp.managed_refuses(activation);
    UPDATE structs.player_address SET status='approved' WHERE player_address.address=address;
    FOREACH value IN ARRAY ARRAY['1','32','48'] LOOP
        UPDATE structs.permission SET val=value::int WHERE id='8-' || address || '@0';
        PERFORM pg_temp.managed_refuses(activation);
    END LOOP;
    UPDATE structs.permission SET val=16 WHERE id='8-' || address || '@0';
    INSERT INTO structs.vault(owner_id,address,account_number) VALUES('1-990940',address,0);
    PERFORM pg_temp.managed_refuses(activation);
    DELETE FROM structs.vault WHERE vault.address=address;
    UPDATE signer.role SET status='pending' WHERE id=990940;
    PERFORM pg_temp.managed_refuses(activation);
    UPDATE signer.role SET status='ready' WHERE id=990940;
    IF NOT signer.ACCOUNT_REGISTRATION_READY_V022(990950,tx_id)
        OR signer.ACTIVATE_ACCOUNT_V022(990950,tx_id)->>'status'<>'available'
        OR signer.ACTIVATE_ACCOUNT_V022(990950,tx_id)->>'status'<>'available' THEN
        RAISE EXCEPTION 'confirmed registration did not activate idempotently';
    END IF;
    PERFORM signer.UPDATE_PENDING_ACCOUNT(990950,'1-990940',address,pubkey,signature,16,context);
    IF (SELECT status FROM signer.account WHERE id=990950)<>'available' THEN
        RAISE EXCEPTION 'registration retry regressed active account';
    END IF;
    PERFORM pg_temp.managed_refuses('UPDATE signer.account SET status=''pending'' WHERE id=990950');
    PERFORM pg_temp.managed_refuses(format('SELECT signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,%s,%L,%L::jsonb)',tx_id,signature,context));

    -- After activation, claim eligibility still reads current ownership. A
    -- terminal transaction can release a key even if a later grant changed.
    UPDATE signer.account SET status='signing' WHERE id=990950;
    UPDATE structs.permission SET val=1 WHERE id='8-' || address || '@0';
    UPDATE structs.player_address SET status='revoked' WHERE player_address.address=address;
    UPDATE signer.account SET status='available' WHERE id=990950;
    IF (SELECT count(*) FROM signer.account_registration WHERE account_id=990950)<>5
        OR (SELECT count(*) FROM signer.tx_unsent_abort)<>1 THEN
        RAISE EXCEPTION 'registration attempt history was lost';
    END IF;
END $$;

ROLLBACK TO SAVEPOINT managed_cases;
-- Same lifecycle as a scoped worker: triggers can enforce private invariants
-- without giving every account updater access to signed bytes/history writes.
CREATE ROLE v022_managed_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_managed_caller;
GRANT SELECT ON signer.role,structs.player,structs.player_address,structs.permission,
    structs.permission_guild_rank,structs.vault,structs.guild,signer.account_registration TO v022_managed_caller;
GRANT UPDATE(id) ON signer.role TO v022_managed_caller;
GRANT SELECT,INSERT,UPDATE ON signer.tx,signer.tx_submission TO v022_managed_caller;
GRANT SELECT,UPDATE ON signer.account TO v022_managed_caller;
GRANT SELECT,INSERT ON signer.tx_authority,signer.tx_registration_proof,signer.tx_unsent_abort TO v022_managed_caller;
GRANT USAGE ON SEQUENCE signer.tx_id_seq TO v022_managed_caller;
GRANT EXECUTE ON FUNCTION signer.CLAIM_TRANSACTION_V022(),structs.api_readiness(TEXT[]),
    signer.CREATE_TRANSACTION_V022(character varying,character varying,structs.signer_tx_module,structs.signer_tx_type,jsonb,jsonb,jsonb),
    signer.CREATE_ADDRESS_REGISTRATION_V022(character varying,character varying,character varying,character varying,character varying,numeric,jsonb),
    signer.SUBMISSION_V022(INTEGER),signer.SAVE_SIGNED_TRANSACTION_V022(INTEGER,UUID,BYTEA,NUMERIC,NUMERIC,NUMERIC,NUMERIC),
    signer.BEGIN_SUBMISSION_V022(INTEGER,UUID),signer.RECORD_SUBMISSION_RESULT_V022(INTEGER,UUID,JSONB),
    signer.ABORT_UNSENT_TRANSACTION_V022(INTEGER,UUID,TEXT),signer.REGISTRATION_FAILED_V022(INTEGER),
    signer.ACTIVATE_ACCOUNT_V022(INTEGER,INTEGER),signer.RENEW_ACCOUNT_REGISTRATION_V022(INTEGER,INTEGER,CHARACTER VARYING,JSONB)
TO v022_managed_caller;
INSERT INTO signer.account(id,role_id,status) VALUES(990950,990940,'generating');
CREATE TEMP TABLE managed_case(tx_id INTEGER);
GRANT ALL ON managed_case TO v022_managed_caller;
SET LOCAL ROLE v022_managed_caller;
DO $$
#variable_conflict use_variable
DECLARE address TEXT := 'structs1' || repeat('s',38); request JSONB; claim JSONB; tx_id INTEGER; token UUID; saved JSONB;
BEGIN
    request := signer.UPDATE_PENDING_ACCOUNT(990950,'1-990940',address,'02' || repeat('ab',32),repeat('cd',64),16,pg_temp.managed_context(address));
    tx_id := (request->>'id')::int;
    claim := signer.CLAIM_TRANSACTION_V022(); token := (claim->'transaction'->>'claim_token')::uuid;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(tx_id,token,'unsigned nonce refresh');
    request := signer.RENEW_ACCOUNT_REGISTRATION_V022(990950,tx_id,repeat('ef',64),pg_temp.managed_context(address));
    tx_id := (request->>'id')::int;
    claim := signer.CLAIM_TRANSACTION_V022(); token := (claim->'transaction'->>'claim_token')::uuid;
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,'scoped-managed'::bytea,0,0,3353000,0);
    PERFORM signer.BEGIN_SUBMISSION_V022(tx_id,token);
    PERFORM signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,jsonb_build_object('stage','deliver_tx',
        'hash',saved->>'tx_hash','code','0','codespace','','log','','height','3353000','index','0','block_hash',repeat('D',64)));
    INSERT INTO managed_case VALUES(tx_id);
    PERFORM pg_temp.managed_refuses(format('SELECT signer.ACTIVATE_ACCOUNT_V022(990950,%s)',tx_id));
END $$;
RESET ROLE;
INSERT INTO structs.player_address(address,player_id,status) VALUES('structs1' || repeat('s',38),'1-990940','approved');
INSERT INTO structs.permission(id,val) VALUES('8-structs1' || repeat('s',38) || '@0',16);
SET LOCAL ROLE v022_managed_caller;
SELECT 1 / ((signer.ACTIVATE_ACCOUNT_V022(990950,(SELECT tx_id FROM managed_case))->>'status')='available')::int;
RESET ROLE;
ROLLBACK;
