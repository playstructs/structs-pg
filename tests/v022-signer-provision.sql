-- Disposable database only. Exercise the actual explicit-key request boundary.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
CREATE FUNCTION pg_temp.provision_refuses(statement TEXT,expected_state TEXT DEFAULT '55000') RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN EXECUTE statement;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE=expected_state THEN RETURN; END IF;
        RAISE;
    END;
    RAISE EXCEPTION 'statement unexpectedly succeeded: %',statement;
END $$;
DO $$
DECLARE request JSONB; repeated JSONB; claimed JSONB; registration JSONB; context JSONB;
    account_id INTEGER; tx_id INTEGER; claim JSONB; value TEXT;
    address TEXT := 'structs1' || repeat('q',38);
BEGIN
    FOREACH value IN ARRAY ARRAY['NULL','0','-1','1.5','18446744073709551616'] LOOP
        PERFORM pg_temp.provision_refuses(format('SELECT signer.REQUEST_ACCOUNT_V022(990940,%s,3,gen_random_uuid(),''queue'')',value),'22023');
    END LOOP;
    PERFORM pg_temp.provision_refuses('SELECT signer.REQUEST_ACCOUNT_V022(990940,16,NULL,gen_random_uuid(),''queue'')','22023');
    PERFORM pg_temp.provision_refuses('SELECT signer.REQUEST_ACCOUNT_V022(990940,16,0,gen_random_uuid(),''queue'')','22023');
    PERFORM pg_temp.provision_refuses('SELECT signer.REQUEST_ACCOUNT_V022(990940,16,3,NULL,''queue'')','22023');
    PERFORM pg_temp.provision_refuses('SELECT signer.REQUEST_ACCOUNT_V022(990940,16,3,gen_random_uuid(),NULL)','22023');

    -- Both existing grants count toward the limit; no automatic 127 fallback.
    IF signer.REQUEST_ACCOUNT_V022(990940,16,2,gen_random_uuid(),'queue') IS NOT NULL THEN
        RAISE EXCEPTION 'existing keys did not count toward pool limit';
    END IF;
    request := signer.REQUEST_ACCOUNT_V022(990940,16,3,'00000000-0000-0000-0000-000000000001','queue');
    account_id := (request->>'id')::integer;
    IF account_id IS NULL OR request->>'permissions'<>'16' OR jsonb_typeof(request->'permissions')<>'string' THEN
        RAISE EXCEPTION 'new key lost its exact explicit grant';
    END IF;
    repeated := signer.REQUEST_ACCOUNT_V022(990940,16,3,'00000000-0000-0000-0000-000000000001','queue');
    IF repeated IS DISTINCT FROM request THEN RAISE EXCEPTION 'request retry did not reuse original identity'; END IF;
    IF signer.REQUEST_ACCOUNT_V022(990940,16,3,gen_random_uuid(),'queue') IS NOT NULL THEN
        RAISE EXCEPTION 'pending generation did not count toward pool limit';
    END IF;
    PERFORM pg_temp.provision_refuses('SELECT signer.REQUEST_ACCOUNT_V022(990940,127,3,''00000000-0000-0000-0000-000000000001'',''queue'')');
    PERFORM pg_temp.provision_refuses('SELECT signer.REQUEST_ACCOUNT_V022(990941,16,3,''00000000-0000-0000-0000-000000000001'',''queue'')');
    PERFORM pg_temp.provision_refuses(format('UPDATE signer.account_request SET permissions=127 WHERE account_id=%s',account_id));
    PERFORM pg_temp.provision_refuses(format('DELETE FROM signer.account_request WHERE account_id=%s',account_id));
    PERFORM pg_temp.provision_refuses(format('UPDATE signer.account SET role_id=990941 WHERE id=%s',account_id));
    PERFORM pg_temp.provision_refuses(format('UPDATE signer.account SET status=''available'' WHERE id=%s',account_id));
    INSERT INTO signer.account(id,role_id,status,created_at) VALUES(990950,990940,'stub','2000-01-01');
    claimed := signer.CLAIM_ACCOUNT_V022();
    IF (claimed->>'id')::integer IS DISTINCT FROM account_id OR claimed->>'permissions'<>'16'
        OR claimed->>'status'<>'generating' OR signer.CLAIM_ACCOUNT_V022() IS NOT NULL THEN
        RAISE EXCEPTION 'generation claimed a legacy stub, repeated claim or lost grant';
    END IF;
    PERFORM pg_temp.provision_refuses(format('UPDATE signer.account SET status=''available'' WHERE id=%s',account_id));
    PERFORM pg_temp.provision_refuses(format('UPDATE signer.account SET status=''pending'' WHERE id=%s',account_id));
    context := jsonb_build_object('chain_id','structstestnet-111','protocol','v0.22.0','source_height','3353000',
        'player_id','1-990940','address',address,'proof_nonce','0','registered_player_id','','timeout_height','0');
    PERFORM pg_temp.provision_refuses(format('SELECT signer.UPDATE_PENDING_ACCOUNT(%s,''1-990940'',%L,%L,%L,127,%L::jsonb)',
        account_id,address,'02' || repeat('ab',32),repeat('cd',64),context));
    registration := signer.UPDATE_PENDING_ACCOUNT(account_id,'1-990940',address,'02' || repeat('ab',32),repeat('cd',64),16,context);
    tx_id := (registration->>'id')::integer;
    IF (SELECT count(*) FROM signer.tx_registration_proof p WHERE p.address=context->>'address')<>1 THEN
        RAISE EXCEPTION 'failed mask change left an orphan registration';
    END IF;
    claim := signer.CLAIM_TRANSACTION_V022();
    IF (claim->'transaction'->>'id')::integer IS DISTINCT FROM tx_id THEN RAISE EXCEPTION 'registration not claimed'; END IF;
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(tx_id,(claim->'transaction'->>'claim_token')::uuid,'stale proof before signing');
    registration := signer.RENEW_ACCOUNT_REGISTRATION_V022(account_id,tx_id,repeat('ef',64),context || '{"proof_nonce":"1"}'::jsonb);
    IF (signer.REGISTRATION_PROOF_V022((registration->>'id')::integer)->>'permissions')<>'16'
        OR signer.ACCOUNT_REQUEST_V022(account_id)->>'permissions'<>'16' THEN
        RAISE EXCEPTION 'proof renewal changed explicit request grant';
    END IF;
    IF (SELECT val FROM structs.permission WHERE id='8-queuekeya@0')<>33554431
        OR (SELECT val FROM structs.permission WHERE id='8-queuerestricted@0')<>16 THEN
        RAISE EXCEPTION 'provisioning changed an existing grant';
    END IF;

    request := signer.REQUEST_ACCOUNT_V022(990941,18446744073709551615,2,gen_random_uuid(),'manual');
    IF request->>'permissions'<>'18446744073709551615' THEN RAISE EXCEPTION 'uint64 mask lost precision'; END IF;
    UPDATE sync_state.sync_cursor SET status='syncing';
    IF signer.CLAIM_ACCOUNT_V022() IS NOT NULL OR signer.REQUEST_ACCOUNT_V022(990941,16,3,gen_random_uuid(),'queue') IS NOT NULL THEN
        RAISE EXCEPTION 'unready state allowed new generation';
    END IF;
    repeated := signer.REQUEST_ACCOUNT_V022(990940,16,3,'00000000-0000-0000-0000-000000000001','queue');
    IF (repeated->>'id')::integer IS DISTINCT FROM account_id THEN RAISE EXCEPTION 'readiness loss hid an existing request'; END IF;
END $$;
ROLLBACK;
