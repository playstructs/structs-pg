-- Disposable PostgreSQL only. Opaque bytes test persistence/hash identity, not
-- chain signatures: the worker must decode, validate and simulate real TxRaw.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql

CREATE FUNCTION pg_temp.expect_submission_error(statement TEXT,expected_state TEXT DEFAULT '55000') RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE=expected_state THEN RETURN; END IF;
        RAISE;
    END;
    RAISE EXCEPTION 'statement unexpectedly succeeded: %',statement;
END $$;

CREATE FUNCTION pg_temp.claim_submission() RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE request JSONB;
BEGIN
    request := signer.CREATE_TRANSACTION_V022('1-990940','1-990940','structs','reactor-infuse',
        '["validator","9007199254740993ualpha"]','{"owner-id":"1-990940"}',
        '[{"check_type":"object","object_id":"1-990940","permission":32}]');
    RETURN signer.CLAIM_TRANSACTION_V022();
END $$;

DO $$
DECLARE claim JSONB; tx_id INTEGER; token UUID; saved JSONB; result JSONB; receipt JSONB; other JSONB;
BEGIN
    claim := pg_temp.claim_submission(); tx_id := (claim->'transaction'->>'id')::int;
    token := (claim->'transaction'->>'claim_token')::uuid;
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.transaction_error(%s,''legacy failure'')',tx_id));
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.transaction_broadcast_results(%s,''stdout'')',tx_id));
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,gen_random_uuid(),''abc''::bytea,0,0,3353000,0)',tx_id));
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,''abc''::bytea,0.5,0,3353000,0)',tx_id,token),'22023');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,''abc''::bytea,0,18446744073709551616,3353000,0)',tx_id,token),'22023');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,''abc''::bytea,0,0,3353000,3353000)',tx_id,token),'22023');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,''''::bytea,0,0,3353000,0)',tx_id,token),'22023');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,decode(repeat(''00'',1048577),''hex''),0,0,3353000,0)',tx_id,token),'22023');
    UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,''abc''::bytea,0,0,3353000,0)',tx_id,token));
    UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,'abc'::bytea,18446744073709551615,9007199254740993,3353000,0);
    IF saved->>'tx_hash'<>'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'
        OR saved->>'state'<>'prepared' OR saved->>'sequence'<>'9007199254740993'
        OR jsonb_typeof(saved->'sequence')<>'string' OR saved->>'account_number'<>'18446744073709551615'
        OR saved->'request'->'transaction'->'args'->>1<>'9007199254740993ualpha' THEN
        RAISE EXCEPTION 'signed bytes/hash or exact context were not preserved';
    END IF;
    IF signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,'abc'::bytea,18446744073709551615,9007199254740993,3353000,0) IS DISTINCT FROM saved THEN
        RAISE EXCEPTION 'identical save was not idempotent';
    END IF;
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.SAVE_SIGNED_TRANSACTION_V022(%s,%L,''changed''::bytea,0,0,3353000,0)',tx_id,token));
    PERFORM pg_temp.expect_submission_error(format('UPDATE signer.tx_submission SET signed_bytes=''changed''::bytea WHERE tx_id=%s',tx_id));
    PERFORM pg_temp.expect_submission_error(format('UPDATE signer.tx SET args=''[]'' WHERE id=%s',tx_id));
    PERFORM pg_temp.expect_submission_error(format('UPDATE signer.tx_authority SET permission=16 WHERE tx_id=%s',tx_id));
    PERFORM pg_temp.expect_submission_error(format('DELETE FROM signer.tx_submission WHERE tx_id=%s',tx_id));
    PERFORM pg_temp.expect_submission_error('UPDATE signer.account SET status=''available'' WHERE id=990940');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.MARK_SUBMISSION_UNKNOWN_V022(%s,%L,''timeout'')',tx_id,token));
    UPDATE structs.permission SET val=16 WHERE id='8-queuekeya@0';
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.BEGIN_SUBMISSION_V022(%s,%L)',tx_id,token));
    UPDATE structs.permission SET val=33554431 WHERE id='8-queuekeya@0';
    IF NOT signer.BEGIN_SUBMISSION_V022(tx_id,token) OR signer.BEGIN_SUBMISSION_V022(tx_id,token) THEN
        RAISE EXCEPTION 'send permit was not exclusive';
    END IF;
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.ABORT_UNSENT_TRANSACTION_V022(%s,%L,''timeout'')',tx_id,token));
    saved := signer.MARK_SUBMISSION_UNKNOWN_V022(tx_id,token,'transport timeout');
    IF saved->>'state'<>'unknown' OR signer.BEGIN_SUBMISSION_V022(tx_id,token)
        OR (SELECT status FROM signer.account WHERE id=990940)<>'signing' THEN
        RAISE EXCEPTION 'unknown submission lost its account reservation or allowed resend';
    END IF;
    result := jsonb_build_object('stage','check_tx','hash',saved->>'tx_hash','code','0','codespace','','log','');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.RECORD_SUBMISSION_RESULT_V022(%s,%L,%L)',tx_id,token,result||'{"hash":"wrong"}'),'22023');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.RECORD_SUBMISSION_RESULT_V022(%s,%L,%L)',tx_id,token,result||'{"code":0}'),'22023');
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.RECORD_SUBMISSION_RESULT_V022(%s,%L,%L)',tx_id,token,result||'{"code":"4294967296"}'),'22023');
    saved := signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,result);
    IF saved->>'state'<>'accepted' OR (SELECT status FROM signer.account WHERE id=990940)<>'signing' THEN
        RAISE EXCEPTION 'CheckTx success was mistaken for inclusion';
    END IF;
    IF signer.MARK_SUBMISSION_UNKNOWN_V022(tx_id,token,'late timeout')->>'state'<>'accepted' THEN
        RAISE EXCEPTION 'late transport result erased admission';
    END IF;
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.RECORD_SUBMISSION_RESULT_V022(%s,%L,%L)',tx_id,token,result||'{"code":"32"}'));
    receipt := result || jsonb_build_object('stage','deliver_tx','height','3353001','index','0','block_hash',repeat('A',64));
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.RECORD_SUBMISSION_RESULT_V022(%s,%L,%L)',tx_id,token,receipt||'{"height":"3352999"}'),'22023');
    saved := signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,receipt);
    IF saved->>'state'<>'committed' OR saved->'deliver_tx' IS DISTINCT FROM receipt
        OR (SELECT status FROM signer.account WHERE id=990940)<>'available' THEN
        RAISE EXCEPTION 'committed success did not retain receipt and release account';
    END IF;
    other := pg_temp.claim_submission();
    PERFORM signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,receipt);
    PERFORM signer.MARK_SUBMISSION_UNKNOWN_V022(tx_id,token,'late old timeout');
    IF (SELECT status FROM signer.account WHERE id=990940)<>'signing' THEN
        RAISE EXCEPTION 'duplicate old result released a new request''s account';
    END IF;
    PERFORM pg_temp.expect_submission_error(format('SELECT signer.RECORD_SUBMISSION_RESULT_V022(%s,%L,%L)',tx_id,token,receipt||'{"code":"5"}'));
    PERFORM signer.ABORT_UNSENT_TRANSACTION_V022((other->'transaction'->>'id')::int,(other->'transaction'->>'claim_token')::uuid,'simulation rejected');
END $$;

DO $$
DECLARE claim JSONB; tx_id INTEGER; token UUID; saved JSONB; outcome JSONB; mode TEXT;
BEGIN
    FOREACH mode IN ARRAY ARRAY['rejected','failed-inclusion','cancelled'] LOOP
        claim := pg_temp.claim_submission(); tx_id := (claim->'transaction'->>'id')::int;
        token := (claim->'transaction'->>'claim_token')::uuid;
        saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,convert_to(mode,'UTF8'),0,0,3353000,3353010);
        IF mode='cancelled' THEN
            saved := signer.ABORT_UNSENT_TRANSACTION_V022(tx_id,token,'unsent stale intent');
            PERFORM signer.ABORT_UNSENT_TRANSACTION_V022(tx_id,token,'unsent stale intent');
        ELSE
            PERFORM signer.BEGIN_SUBMISSION_V022(tx_id,token);
            outcome := jsonb_build_object('stage','check_tx','hash',saved->>'tx_hash','code','5','codespace','sdk','log','confirmed refusal');
            IF mode='failed-inclusion' THEN
                PERFORM signer.MARK_SUBMISSION_UNKNOWN_V022(tx_id,token,'process interrupted');
                outcome := outcome || jsonb_build_object('stage','deliver_tx','height','3353011','index','2','block_hash',repeat('B',64));
            END IF;
            saved := signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,outcome);
        END IF;
        IF (SELECT status FROM signer.tx WHERE id=tx_id)<>'error' OR (SELECT status FROM signer.account WHERE id=990940)<>'available'
            OR saved->>'state'<>(CASE WHEN mode='failed-inclusion' THEN 'committed' ELSE mode END)
            OR signer.BEGIN_SUBMISSION_V022(tx_id,token) THEN
            RAISE EXCEPTION 'definitive outcome did not release key or incorrectly allowed resend: %',mode;
        END IF;
    END LOOP;
    -- Legacy behavior is preserved only for legacy requests.
    INSERT INTO signer.tx(module,command) VALUES('structs','reactor-infuse') RETURNING id INTO tx_id;
    PERFORM signer.TRANSACTION_BROADCAST_RESULTS(tx_id,'legacy stdout');
    PERFORM signer.TRANSACTION_ERROR(tx_id,'legacy error');
    IF (SELECT status FROM signer.tx WHERE id=tx_id)<>'error' THEN RAISE EXCEPTION 'legacy outcome path broke'; END IF;
END $$;

-- Scoped worker calls exercise every transition without superuser rights.
CREATE ROLE v022_submission_caller NOLOGIN NOSUPERUSER;
GRANT USAGE ON SCHEMA signer,structs TO v022_submission_caller;
GRANT SELECT ON signer.role,structs.player,structs.player_address,structs.permission,
    structs.permission_guild_rank,structs.vault,structs.guild,signer.tx_registration_proof TO v022_submission_caller;
GRANT SELECT,INSERT,UPDATE ON signer.tx,signer.tx_submission TO v022_submission_caller;
GRANT SELECT,UPDATE ON signer.account TO v022_submission_caller;
GRANT SELECT,INSERT ON signer.tx_authority TO v022_submission_caller;
GRANT USAGE ON SEQUENCE signer.tx_id_seq TO v022_submission_caller;
GRANT EXECUTE ON FUNCTION signer.CLAIM_TRANSACTION_V022(),structs.api_readiness(TEXT[]),
    signer.CREATE_TRANSACTION_V022(character varying,character varying,structs.signer_tx_module,structs.signer_tx_type,jsonb,jsonb,jsonb),
    signer.SUBMISSION_V022(INTEGER),signer.SAVE_SIGNED_TRANSACTION_V022(INTEGER,UUID,BYTEA,NUMERIC,NUMERIC,NUMERIC,NUMERIC),
    signer.BEGIN_SUBMISSION_V022(INTEGER,UUID),signer.MARK_SUBMISSION_UNKNOWN_V022(INTEGER,UUID,TEXT),
    signer.RECORD_SUBMISSION_RESULT_V022(INTEGER,UUID,JSONB),signer.ABORT_UNSENT_TRANSACTION_V022(INTEGER,UUID,TEXT)
TO v022_submission_caller;
SET LOCAL ROLE v022_submission_caller;
DO $$
DECLARE claim JSONB; tx_id INTEGER; token UUID; saved JSONB;
BEGIN
    claim := pg_temp.claim_submission(); tx_id := (claim->'transaction'->>'id')::int;
    token := (claim->'transaction'->>'claim_token')::uuid;
    saved := signer.SAVE_SIGNED_TRANSACTION_V022(tx_id,token,'scoped'::bytea,0,0,3353000,0);
    PERFORM signer.BEGIN_SUBMISSION_V022(tx_id,token);
    PERFORM signer.MARK_SUBMISSION_UNKNOWN_V022(tx_id,token,'transport interrupted');
    saved := signer.RECORD_SUBMISSION_RESULT_V022(tx_id,token,jsonb_build_object('stage','deliver_tx',
        'hash',saved->>'tx_hash','code','0','codespace','','log','','height','3353001','index','0','block_hash',repeat('C',64)));
    IF saved->>'state'<>'committed' OR (SELECT status FROM signer.account WHERE id=990940)<>'available' THEN
        RAISE EXCEPTION 'scoped worker failed durable inclusion lifecycle';
    END IF;
END $$;
RESET ROLE;
ROLLBACK;
