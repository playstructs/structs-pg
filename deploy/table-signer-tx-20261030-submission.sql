-- Deploy structs-pg:table-signer-tx-20261030-submission to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'submission lifecycle requires the coordinated v022-1 signer contract';
    END IF;
END $$;

-- One signed identity per request. Recovery observes this identity; it never
-- constructs a replacement from an uncertain transport result.
CREATE TABLE signer.tx_submission (
    tx_id INTEGER PRIMARY KEY REFERENCES signer.tx(id) ON DELETE RESTRICT,
    claim_token UUID NOT NULL,
    account_id INTEGER NOT NULL REFERENCES signer.account(id) ON DELETE RESTRICT,
    address CHARACTER VARYING NOT NULL,
    chain_id TEXT NOT NULL CHECK (chain_id='structstestnet-111'),
    signed_bytes BYTEA NOT NULL CHECK (octet_length(signed_bytes) BETWEEN 1 AND 1048576),
    tx_hash TEXT GENERATED ALWAYS AS (upper(encode(sha256(signed_bytes),'hex'))) STORED,
    account_number NUMERIC NOT NULL CHECK (account_number BETWEEN 0 AND 18446744073709551615 AND account_number=trunc(account_number)),
    sequence NUMERIC NOT NULL CHECK (sequence BETWEEN 0 AND 18446744073709551615 AND sequence=trunc(sequence)),
    source_height BIGINT NOT NULL CHECK (source_height BETWEEN 3353000 AND 9007199254740991),
    timeout_height BIGINT NOT NULL CHECK (timeout_height=0 OR timeout_height BETWEEN source_height+1 AND 9007199254740991),
    request JSONB NOT NULL,
    state TEXT NOT NULL DEFAULT 'prepared' CHECK (state IN ('prepared','sending','unknown','accepted','rejected','committed','cancelled')),
    check_tx JSONB,
    deliver_tx JSONB,
    local_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    send_started_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(chain_id,tx_hash),
    CHECK ((state='prepared' AND send_started_at IS NULL AND resolved_at IS NULL)
        OR (state IN ('sending','unknown','accepted') AND send_started_at IS NOT NULL AND resolved_at IS NULL)
        OR (state IN ('rejected','committed') AND send_started_at IS NOT NULL AND resolved_at IS NOT NULL)
        OR (state='cancelled' AND send_started_at IS NULL AND resolved_at IS NOT NULL)),
    CHECK ((state IN ('accepted','rejected'))=(check_tx IS NOT NULL AND deliver_tx IS NULL)
        OR state='committed'),
    CHECK ((state='committed')=(deliver_tx IS NOT NULL))
);
CREATE UNIQUE INDEX signer_submission_active_account_idx ON signer.tx_submission(account_id)
    WHERE state IN ('prepared','sending','unknown','accepted');
CREATE INDEX signer_submission_recovery_idx ON signer.tx_submission(updated_at,tx_id)
    WHERE state IN ('prepared','sending','unknown','accepted');

CREATE FUNCTION signer.SUBMISSION_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql AS $BODY$
BEGIN
    IF TG_OP='DELETE' THEN
        RAISE EXCEPTION 'signed submission history cannot be deleted' USING ERRCODE='55000';
    END IF;
    IF (to_jsonb(NEW)-ARRAY['state','check_tx','deliver_tx','local_error','send_started_at','resolved_at','updated_at','tx_hash'])
        IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['state','check_tx','deliver_tx','local_error','send_started_at','resolved_at','updated_at','tx_hash']) THEN
        RAISE EXCEPTION 'signed submission identity is immutable' USING ERRCODE='55000';
    END IF;
    IF OLD.state IN ('rejected','committed','cancelled') AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION 'terminal submission is immutable' USING ERRCODE='55000';
    END IF;
    IF NOT (NEW.state=OLD.state
        OR (OLD.state='prepared' AND NEW.state IN ('sending','cancelled'))
        OR (OLD.state IN ('sending','unknown') AND NEW.state IN ('unknown','accepted','rejected','committed'))
        OR (OLD.state='accepted' AND NEW.state='committed')) THEN
        RAISE EXCEPTION 'invalid submission state transition' USING ERRCODE='55000';
    END IF;
    IF OLD.send_started_at IS NOT NULL AND NEW.send_started_at IS DISTINCT FROM OLD.send_started_at THEN
        RAISE EXCEPTION 'send marker is immutable' USING ERRCODE='55000';
    END IF;
    IF OLD.check_tx IS NOT NULL AND NEW.check_tx IS DISTINCT FROM OLD.check_tx THEN
        RAISE EXCEPTION 'admission result is immutable' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER submission_guard_v022 BEFORE UPDATE OR DELETE ON signer.tx_submission
    FOR EACH ROW EXECUTE FUNCTION signer.SUBMISSION_GUARD_V022();

-- Integrity checks must also run for existing scoped callers, without granting
-- those callers access to other workers' signed transaction bytes.
CREATE FUNCTION signer.SUBMISSION_PARENT_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx_submission WHERE tx_id=OLD.id)
        AND (to_jsonb(NEW)-ARRAY['status','output','updated_at']) IS DISTINCT FROM
            (to_jsonb(OLD)-ARRAY['status','output','updated_at']) THEN
        RAISE EXCEPTION 'signed request identity is immutable' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER submission_parent_guard_v022 BEFORE UPDATE ON signer.tx
    FOR EACH ROW EXECUTE FUNCTION signer.SUBMISSION_PARENT_GUARD_V022();

CREATE FUNCTION signer.SUBMISSION_AUTHORITY_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF (TG_OP<>'INSERT' AND EXISTS (SELECT 1 FROM signer.tx_submission WHERE tx_id=OLD.tx_id))
        OR (TG_OP<>'DELETE' AND EXISTS (SELECT 1 FROM signer.tx_submission WHERE tx_id=NEW.tx_id)) THEN
        RAISE EXCEPTION 'signed request authority is immutable' USING ERRCODE='55000';
    END IF;
    RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END
$BODY$;
CREATE TRIGGER submission_authority_guard_v022 BEFORE INSERT OR UPDATE OR DELETE ON signer.tx_authority
    FOR EACH ROW EXECUTE FUNCTION signer.SUBMISSION_AUTHORITY_GUARD_V022();

CREATE FUNCTION signer.SUBMISSION_ACCOUNT_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx_submission WHERE account_id=OLD.id
        AND state IN ('prepared','sending','unknown','accepted'))
        AND (NEW.status IS DISTINCT FROM 'signing'::structs.signer_account_status
            OR NEW.address IS DISTINCT FROM OLD.address OR NEW.role_id IS DISTINCT FROM OLD.role_id) THEN
        RAISE EXCEPTION 'unresolved signed submission reserves this account' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER submission_account_guard_v022 BEFORE UPDATE ON signer.account
    FOR EACH ROW EXECUTE FUNCTION signer.SUBMISSION_ACCOUNT_GUARD_V022();

CREATE FUNCTION signer.SUBMISSION_V022(_tx_id INTEGER) RETURNS JSONB LANGUAGE sql STABLE AS $BODY$
    SELECT to_jsonb(s) || jsonb_build_object('account_number',trunc(account_number)::text,
        'sequence',trunc(sequence)::text,'source_height',source_height::text,'timeout_height',timeout_height::text)
    FROM signer.tx_submission s WHERE tx_id=_tx_id;
$BODY$;

CREATE FUNCTION signer.SAVE_SIGNED_TRANSACTION_V022(_tx_id INTEGER,_claim_token UUID,_signed_bytes BYTEA,
    _account_number NUMERIC,_sequence NUMERIC,_source_height NUMERIC,_timeout_height NUMERIC)
RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _tx signer.tx%ROWTYPE; _account signer.account%ROWTYPE; _saved signer.tx_submission%ROWTYPE; _context RECORD;
BEGIN
    PERFORM signer.UINT64_ARGUMENT(_account_number,'account number');
    PERFORM signer.UINT64_ARGUMENT(_sequence,'sequence');
    PERFORM signer.UINT64_ARGUMENT(_source_height,'source height',FALSE);
    PERFORM signer.UINT64_ARGUMENT(_timeout_height,'timeout height');
    IF _source_height NOT BETWEEN 3353000 AND 9007199254740991
        OR (_timeout_height<>0 AND _timeout_height NOT BETWEEN _source_height+1 AND 9007199254740991)
        OR _signed_bytes IS NULL OR octet_length(_signed_bytes) NOT BETWEEN 1 AND 1048576 THEN
        RAISE EXCEPTION 'invalid signed submission context or byte size' USING ERRCODE='22023';
    END IF;
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id FOR UPDATE;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _tx.claim_token IS DISTINCT FROM _claim_token
        OR _claim_token IS NULL THEN
        RAISE EXCEPTION 'invalid submission claim' USING ERRCODE='55000';
    END IF;
    SELECT * INTO _saved FROM signer.tx_submission WHERE tx_id=_tx_id;
    IF FOUND THEN
        IF _saved.signed_bytes IS DISTINCT FROM _signed_bytes OR _saved.account_number<>_account_number
            OR _saved.sequence<>_sequence OR _saved.source_height<>_source_height OR _saved.timeout_height<>_timeout_height THEN
            RAISE EXCEPTION 'request already has a different signed identity' USING ERRCODE='55000';
        END IF;
        RETURN signer.SUBMISSION_V022(_tx_id);
    END IF;
    SELECT * INTO _account FROM signer.account WHERE id=_tx.account_id FOR UPDATE;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _tx.status<>'claimed' OR _account.status IS DISTINCT FROM 'signing'::structs.signer_account_status
        OR _context.transaction_ready IS DISTINCT FROM TRUE OR _context.chain_id IS DISTINCT FROM _tx.chain_id
        OR _source_height<_tx.prepared_height OR _source_height<_context.indexed_height::bigint
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(_tx_id) WHERE account_id=_account.id) THEN
        RAISE EXCEPTION 'claim is no longer ready or authorized for signing' USING ERRCODE='55000';
    END IF;
    INSERT INTO signer.tx_submission(tx_id,claim_token,account_id,address,chain_id,signed_bytes,
        account_number,sequence,source_height,timeout_height,request)
    VALUES(_tx_id,_claim_token,_account.id,_account.address,_tx.chain_id,_signed_bytes,
        _account_number,_sequence,_source_height,_timeout_height,
        jsonb_build_object('transaction',to_jsonb(_tx),'authority',(SELECT jsonb_agg(to_jsonb(a) ORDER BY check_type,object_id,permission)
            FROM signer.tx_authority a WHERE tx_id=_tx_id),'registration_proof',signer.REGISTRATION_PROOF_V022(_tx_id)));
    RETURN signer.SUBMISSION_V022(_tx_id);
END
$BODY$;

-- TRUE grants this caller the sole transport attempt. FALSE is observation,
-- including a restart after a crash between this commit and network I/O.
CREATE FUNCTION signer.BEGIN_SUBMISSION_V022(_tx_id INTEGER,_claim_token UUID) RETURNS BOOLEAN
LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _tx signer.tx%ROWTYPE; _saved signer.tx_submission%ROWTYPE; _context RECORD;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id FOR UPDATE;
    SELECT * INTO _saved FROM signer.tx_submission WHERE tx_id=_tx_id FOR UPDATE;
    IF NOT FOUND OR _claim_token IS NULL OR _saved.claim_token IS DISTINCT FROM _claim_token THEN
        RAISE EXCEPTION 'invalid submission claim' USING ERRCODE='55000';
    END IF;
    IF _saved.state<>'prepared' THEN RETURN FALSE; END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _tx.status<>'claimed' OR _context.transaction_ready IS DISTINCT FROM TRUE
        OR _context.chain_id IS DISTINCT FROM _saved.chain_id
        OR (_saved.timeout_height<>0 AND _context.indexed_height::bigint>=_saved.timeout_height)
        OR NOT EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(_tx_id) WHERE account_id=_saved.account_id AND status='signing') THEN
        RAISE EXCEPTION 'submission is no longer ready or authorized' USING ERRCODE='55000';
    END IF;
    UPDATE signer.tx_submission SET state='sending',send_started_at=NOW(),updated_at=NOW() WHERE tx_id=_tx_id;
    UPDATE signer.tx SET status='broadcast',updated_at=NOW() WHERE id=_tx_id;
    RETURN TRUE;
END
$BODY$;

CREATE FUNCTION signer.MARK_SUBMISSION_UNKNOWN_V022(_tx_id INTEGER,_claim_token UUID,_reason TEXT) RETURNS JSONB
LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _saved signer.tx_submission%ROWTYPE;
BEGIN
    PERFORM 1 FROM signer.tx WHERE id=_tx_id FOR UPDATE;
    SELECT * INTO _saved FROM signer.tx_submission WHERE tx_id=_tx_id FOR UPDATE;
    IF NOT FOUND OR _claim_token IS NULL OR _saved.claim_token IS DISTINCT FROM _claim_token THEN
        RAISE EXCEPTION 'invalid submission claim' USING ERRCODE='55000';
    END IF;
    IF _reason IS NULL OR length(_reason) NOT BETWEEN 1 AND 8192 THEN
        RAISE EXCEPTION 'transport reason is required and bounded' USING ERRCODE='22023';
    END IF;
    IF _saved.state='prepared' THEN RAISE EXCEPTION 'submission has not begun' USING ERRCODE='55000'; END IF;
    IF _saved.state IN ('sending','unknown') THEN
        UPDATE signer.tx_submission SET state='unknown',local_error=_reason,updated_at=NOW() WHERE tx_id=_tx_id;
    END IF;
    -- A late timeout cannot undo authoritative admission/inclusion evidence.
    RETURN signer.SUBMISSION_V022(_tx_id);
END
$BODY$;

CREATE FUNCTION signer.RECORD_SUBMISSION_RESULT_V022(_tx_id INTEGER,_claim_token UUID,_result JSONB) RETURNS JSONB
LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _saved signer.tx_submission%ROWTYPE; _stage TEXT; _code BIGINT;
BEGIN
    PERFORM 1 FROM signer.tx WHERE id=_tx_id FOR UPDATE;
    SELECT * INTO _saved FROM signer.tx_submission WHERE tx_id=_tx_id FOR UPDATE;
    IF NOT FOUND OR _claim_token IS NULL OR _saved.claim_token IS DISTINCT FROM _claim_token THEN
        RAISE EXCEPTION 'invalid submission claim' USING ERRCODE='55000';
    END IF;
    IF _result IS NULL OR jsonb_typeof(_result)<>'object' THEN
        RAISE EXCEPTION 'result must be an object' USING ERRCODE='22023';
    END IF;
    _stage := _result->>'stage';
    IF _stage IS NULL OR _stage NOT IN ('check_tx','deliver_tx')
        OR EXISTS (SELECT 1 FROM jsonb_each(_result) WHERE jsonb_typeof(value)<>'string')
        OR NOT _result ?& ARRAY['stage','hash','code','codespace','log']
        OR _result->>'hash' IS DISTINCT FROM _saved.tx_hash
        OR _result->>'code' !~ '^(0|[1-9][0-9]{0,9})$'
        OR length(_result->>'codespace')>128 OR length(_result->>'log')>8192 THEN
        RAISE EXCEPTION 'invalid result identity or exact string fields' USING ERRCODE='22023';
    END IF;
    _code := (_result->>'code')::bigint;
    IF _code>4294967295 THEN RAISE EXCEPTION 'result code exceeds uint32' USING ERRCODE='22023'; END IF;
    IF _stage='check_tx' THEN
        IF (_result-ARRAY['stage','hash','code','codespace','log'])<>'{}'::jsonb THEN
            RAISE EXCEPTION 'invalid admission result fields' USING ERRCODE='22023';
        END IF;
        IF _saved.check_tx IS NOT NULL THEN
            IF _saved.check_tx IS DISTINCT FROM _result THEN RAISE EXCEPTION 'conflicting admission result' USING ERRCODE='55000'; END IF;
            RETURN signer.SUBMISSION_V022(_tx_id);
        END IF;
        IF _saved.state NOT IN ('sending','unknown') THEN
            RAISE EXCEPTION 'admission result cannot change this submission' USING ERRCODE='55000';
        END IF;
        UPDATE signer.tx_submission SET state=CASE WHEN _code=0 THEN 'accepted' ELSE 'rejected' END,
            check_tx=_result,resolved_at=CASE WHEN _code<>0 THEN NOW() END,updated_at=NOW() WHERE tx_id=_tx_id;
    ELSE
        IF NOT _result ?& ARRAY['height','index','block_hash']
            OR (_result-ARRAY['stage','hash','code','codespace','log','height','index','block_hash'])<>'{}'::jsonb
            OR _result->>'height' !~ '^[1-9][0-9]{0,15}$'
            OR _result->>'index' !~ '^(0|[1-9][0-9]{0,9})$' OR _result->>'block_hash' !~ '^[0-9A-F]{64}$' THEN
            RAISE EXCEPTION 'invalid inclusion coordinates' USING ERRCODE='22023';
        END IF;
        IF (_result->>'height')::numeric NOT BETWEEN _saved.source_height AND 9007199254740991
            OR (_result->>'index')::bigint>4294967295 THEN
            RAISE EXCEPTION 'inclusion coordinates outside range' USING ERRCODE='22023';
        END IF;
        IF _saved.deliver_tx IS NOT NULL THEN
            IF _saved.deliver_tx IS DISTINCT FROM _result THEN RAISE EXCEPTION 'conflicting inclusion result' USING ERRCODE='55000'; END IF;
            RETURN signer.SUBMISSION_V022(_tx_id);
        END IF;
        IF _saved.state NOT IN ('sending','unknown','accepted') THEN
            RAISE EXCEPTION 'inclusion result cannot change this submission' USING ERRCODE='55000';
        END IF;
        UPDATE signer.tx_submission SET state='committed',deliver_tx=_result,resolved_at=NOW(),updated_at=NOW() WHERE tx_id=_tx_id;
    END IF;
    IF _stage='deliver_tx' OR _code<>0 THEN
        UPDATE signer.tx SET status=CASE WHEN _code=0 THEN 'broadcast' ELSE 'error' END::structs.signer_tx_status,
            output=_result::text,updated_at=NOW() WHERE id=_tx_id;
        UPDATE signer.account SET status='available',updated_at=NOW() WHERE id=_saved.account_id;
    END IF;
    RETURN signer.SUBMISSION_V022(_tx_id);
END
$BODY$;

CREATE FUNCTION signer.ABORT_UNSENT_TRANSACTION_V022(_tx_id INTEGER,_claim_token UUID,_reason TEXT) RETURNS JSONB
LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _tx signer.tx%ROWTYPE; _saved signer.tx_submission%ROWTYPE;
BEGIN
    SELECT * INTO _tx FROM signer.tx WHERE id=_tx_id FOR UPDATE;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _claim_token IS NULL OR _tx.claim_token IS DISTINCT FROM _claim_token THEN
        RAISE EXCEPTION 'invalid submission claim' USING ERRCODE='55000';
    END IF;
    IF _reason IS NULL OR length(_reason) NOT BETWEEN 1 AND 8192 THEN
        RAISE EXCEPTION 'unsent failure reason is required and bounded' USING ERRCODE='22023';
    END IF;
    SELECT * INTO _saved FROM signer.tx_submission WHERE tx_id=_tx_id FOR UPDATE;
    IF FOUND THEN
        IF _saved.state='cancelled' AND _saved.local_error=_reason THEN RETURN signer.SUBMISSION_V022(_tx_id); END IF;
        IF _saved.state<>'prepared' THEN RAISE EXCEPTION 'send-marked identity cannot be cancelled or replaced' USING ERRCODE='55000'; END IF;
        UPDATE signer.tx_submission SET state='cancelled',local_error=_reason,resolved_at=NOW(),updated_at=NOW() WHERE tx_id=_tx_id;
    ELSIF _tx.status='error' AND _tx.output=_reason THEN
        RETURN to_jsonb(_tx);
    ELSIF _tx.status<>'claimed' THEN
        RAISE EXCEPTION 'request is not an unsent claim' USING ERRCODE='55000';
    END IF;
    UPDATE signer.tx SET status='error',output=_reason,updated_at=NOW() WHERE id=_tx_id RETURNING * INTO _tx;
    UPDATE signer.account SET status='available',updated_at=NOW() WHERE id=_tx.account_id;
    RETURN COALESCE(signer.SUBMISSION_V022(_tx_id),to_jsonb(_tx));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.transaction_error(transaction_id INTEGER,transaction_error TEXT)
RETURNS VOID LANGUAGE plpgsql AS $BODY$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE id=transaction_id AND contract IS NOT NULL) THEN
        RAISE EXCEPTION 'versioned requests require the durable submission lifecycle' USING ERRCODE='55000';
    END IF;
    UPDATE signer.tx SET status='error',output=transaction_error,updated_at=NOW() WHERE id=transaction_id AND contract IS NULL;
END
$BODY$;
CREATE OR REPLACE FUNCTION signer.transaction_broadcast_results(transaction_id INTEGER,transaction_output TEXT)
RETURNS VOID LANGUAGE plpgsql AS $BODY$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE id=transaction_id AND contract IS NOT NULL) THEN
        RAISE EXCEPTION 'versioned requests require the durable submission lifecycle' USING ERRCODE='55000';
    END IF;
    UPDATE signer.tx SET status='broadcast',output=transaction_output,updated_at=NOW() WHERE id=transaction_id AND contract IS NULL;
END
$BODY$;

-- Invoker functions: the deployed worker receives explicit table/function
-- grants in its packaging contract, never a public signing mutation API.
REVOKE ALL ON FUNCTION signer.SUBMISSION_V022(INTEGER),
    signer.SAVE_SIGNED_TRANSACTION_V022(INTEGER,UUID,BYTEA,NUMERIC,NUMERIC,NUMERIC,NUMERIC),
    signer.BEGIN_SUBMISSION_V022(INTEGER,UUID),signer.MARK_SUBMISSION_UNKNOWN_V022(INTEGER,UUID,TEXT),
    signer.RECORD_SUBMISSION_RESULT_V022(INTEGER,UUID,JSONB),
    signer.ABORT_UNSENT_TRANSACTION_V022(INTEGER,UUID,TEXT) FROM PUBLIC;
COMMIT;
