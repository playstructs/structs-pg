-- Deploy structs-pg:function-signer-account-20261030-registration-lifecycle to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'managed registration requires the coordinated v022-1 signer contract';
    END IF;
END $$;
LOCK TABLE signer.account IN SHARE ROW EXCLUSIVE MODE;

-- A failure before signing has no tx_submission row. Retain the explicit
-- unsent decision instead of treating an arbitrary tx.status='error' as proof
-- that it is safe to create a replacement registration.
CREATE TABLE signer.tx_unsent_abort (
    tx_id INTEGER PRIMARY KEY REFERENCES signer.tx(id) ON DELETE RESTRICT,
    claim_token UUID NOT NULL,
    account_id INTEGER NOT NULL REFERENCES signer.account(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL CHECK (length(reason) BETWEEN 1 AND 8192),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE FUNCTION signer.UNSENT_ABORT_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _tx signer.tx%ROWTYPE;
BEGIN
    IF TG_OP<>'INSERT' THEN
        RAISE EXCEPTION 'unsent abort history is immutable' USING ERRCODE='55000';
    END IF;
    SELECT * INTO _tx FROM signer.tx WHERE id=NEW.tx_id FOR UPDATE;
    IF NOT FOUND OR _tx.contract IS DISTINCT FROM 'v022-1' OR _tx.status IS DISTINCT FROM 'error'::structs.signer_tx_status
        OR _tx.claim_token IS DISTINCT FROM NEW.claim_token OR _tx.account_id IS DISTINCT FROM NEW.account_id
        OR _tx.output IS DISTINCT FROM NEW.reason
        OR EXISTS (SELECT 1 FROM signer.tx_submission WHERE tx_id=NEW.tx_id) THEN
        RAISE EXCEPTION 'unsent abort does not match a failed claim without signed bytes' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER unsent_abort_guard_v022 BEFORE INSERT OR UPDATE OR DELETE ON signer.tx_unsent_abort
    FOR EACH ROW EXECUTE FUNCTION signer.UNSENT_ABORT_GUARD_V022();

CREATE FUNCTION signer.UNSENT_ABORT_PARENT_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx_unsent_abort WHERE tx_id=OLD.id) AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION 'aborted unsigned request is immutable' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER unsent_abort_parent_guard_v022 BEFORE UPDATE ON signer.tx
    FOR EACH ROW EXECUTE FUNCTION signer.UNSENT_ABORT_PARENT_GUARD_V022();

CREATE FUNCTION signer.UNSENT_ABORT_AUTHORITY_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
BEGIN
    IF (TG_OP<>'INSERT' AND EXISTS (SELECT 1 FROM signer.tx_unsent_abort WHERE tx_id=OLD.tx_id))
        OR (TG_OP<>'DELETE' AND EXISTS (SELECT 1 FROM signer.tx_unsent_abort WHERE tx_id=NEW.tx_id)) THEN
        RAISE EXCEPTION 'aborted unsigned request authority is immutable' USING ERRCODE='55000';
    END IF;
    RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END
$BODY$;
CREATE TRIGGER unsent_abort_authority_guard_v022 BEFORE INSERT OR UPDATE OR DELETE ON signer.tx_authority
    FOR EACH ROW EXECUTE FUNCTION signer.UNSENT_ABORT_AUTHORITY_GUARD_V022();

CREATE OR REPLACE FUNCTION signer.ABORT_UNSENT_TRANSACTION_V022(_tx_id INTEGER,_claim_token UUID,_reason TEXT) RETURNS JSONB
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
    ELSIF EXISTS (SELECT 1 FROM signer.tx_unsent_abort WHERE tx_id=_tx_id AND claim_token=_claim_token AND reason=_reason) THEN
        RETURN to_jsonb(_tx);
    ELSIF _tx.status<>'claimed' THEN
        RAISE EXCEPTION 'request is not an unsent claim' USING ERRCODE='55000';
    END IF;
    UPDATE signer.tx SET status='error',output=_reason,updated_at=NOW() WHERE id=_tx_id RETURNING * INTO _tx;
    IF _saved.tx_id IS NULL THEN
        INSERT INTO signer.tx_unsent_abort(tx_id,claim_token,account_id,reason)
        VALUES(_tx_id,_claim_token,_tx.account_id,_reason);
    END IF;
    UPDATE signer.account SET status='available',updated_at=NOW() WHERE id=_tx.account_id;
    RETURN COALESCE(signer.SUBMISSION_V022(_tx_id),to_jsonb(_tx));
END
$BODY$;

CREATE OR REPLACE FUNCTION signer.save_signed_transaction_v022(_tx_id integer, _claim_token uuid, _signed_bytes bytea, _account_number numeric, _sequence numeric, _source_height numeric, _timeout_height numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
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
        OR EXISTS (SELECT 1 FROM signer.tx_registration_proof WHERE tx_id=_tx_id AND source_height>_source_height)
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
$function$
;

-- Every attempt retains its original proof and outcome. Replacing the current
-- account link never deletes or reuses the previous request identity.
CREATE TABLE signer.account_registration (
    tx_id INTEGER PRIMARY KEY REFERENCES signer.tx_registration_proof(tx_id) ON DELETE RESTRICT,
    account_id INTEGER NOT NULL REFERENCES signer.account(id) ON DELETE RESTRICT,
    previous_tx_id INTEGER UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(account_id,tx_id),
    FOREIGN KEY(account_id,previous_tx_id) REFERENCES signer.account_registration(account_id,tx_id) ON DELETE RESTRICT,
    CHECK (previous_tx_id IS NULL OR previous_tx_id<>tx_id)
);
CREATE UNIQUE INDEX signer_account_registration_first_idx ON signer.account_registration(account_id)
    WHERE previous_tx_id IS NULL;
INSERT INTO signer.account_registration(tx_id,account_id)
SELECT registration_tx_id,id FROM signer.account WHERE registration_tx_id IS NOT NULL;

CREATE FUNCTION signer.ACCOUNT_REGISTRATION_IMMUTABLE_V022() RETURNS TRIGGER LANGUAGE plpgsql AS $BODY$
BEGIN
    RAISE EXCEPTION 'managed registration history is immutable' USING ERRCODE='55000';
END
$BODY$;
CREATE TRIGGER account_registration_immutable_v022 BEFORE UPDATE OR DELETE ON signer.account_registration
    FOR EACH ROW EXECUTE FUNCTION signer.ACCOUNT_REGISTRATION_IMMUTABLE_V022();

CREATE FUNCTION signer.REGISTRATION_FAILED_V022(_tx_id INTEGER) RETURNS BOOLEAN LANGUAGE sql STABLE AS $BODY$
    SELECT EXISTS (SELECT 1 FROM signer.tx_submission WHERE tx_id=_tx_id
        AND (state='cancelled' OR (state='rejected' AND check_tx->>'code'<>'0')
            OR (state='committed' AND deliver_tx->>'code'<>'0')))
        OR EXISTS (SELECT 1 FROM signer.tx_unsent_abort WHERE tx_id=_tx_id);
$BODY$;

CREATE FUNCTION signer.ACCOUNT_REGISTRATION_READY_V022(_account_id INTEGER,_tx_id INTEGER)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $BODY$
    SELECT EXISTS (
        SELECT 1 FROM signer.account a JOIN signer.role r ON r.id=a.role_id AND r.status='ready'
        JOIN signer.account_registration h ON h.account_id=a.id AND h.tx_id=a.registration_tx_id
        JOIN signer.tx_registration_proof p ON p.tx_id=h.tx_id AND p.address=a.address AND p.player_id=r.player_id
        JOIN signer.tx_submission s ON s.tx_id=p.tx_id AND s.chain_id=p.chain_id
        JOIN structs.player_address pa ON pa.address=p.address AND pa.status='approved' AND pa.player_id=p.player_id
        JOIN structs.player player ON player.id=pa.player_id
        JOIN structs.permission permission ON permission.id='8-' || p.address || '@0' AND permission.val=p.permissions
        CROSS JOIN structs.api_readiness(ARRAY[]::TEXT[]) context
        WHERE a.id=_account_id AND p.tx_id=_tx_id AND s.state='committed' AND s.deliver_tx->>'code'='0'
            AND s.request->'registration_proof'=signer.REGISTRATION_PROOF_V022(p.tx_id)
            AND context.data_ready AND context.chain_id=p.chain_id AND context.protocol=p.protocol
            AND context.indexed_height::bigint>=(s.deliver_tx->>'height')::bigint
            AND NOT EXISTS (SELECT 1 FROM structs.vault v WHERE v.address=p.address)
    );
$BODY$;

CREATE FUNCTION signer.ACCOUNT_REGISTRATION_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _proof signer.tx_registration_proof%ROWTYPE; _previous signer.tx_registration_proof%ROWTYPE;
BEGIN
    IF TG_OP='INSERT' THEN
        IF NEW.registration_tx_id IS NOT NULL THEN
            RAISE EXCEPTION 'managed registration must begin with a generated account' USING ERRCODE='55000';
        END IF;
        RETURN NEW;
    END IF;
    IF OLD.registration_tx_id IS NULL AND NEW.registration_tx_id IS NULL THEN RETURN NEW; END IF;
    IF OLD.registration_tx_id IS NOT NULL AND (NEW.id IS DISTINCT FROM OLD.id
        OR NEW.role_id IS DISTINCT FROM OLD.role_id OR NEW.address IS DISTINCT FROM OLD.address
        OR NEW.registration_tx_id IS NULL) THEN
        RAISE EXCEPTION 'managed account identity and registration history cannot be detached' USING ERRCODE='55000';
    END IF;
    IF NEW.registration_tx_id IS DISTINCT FROM OLD.registration_tx_id THEN
        SELECT * INTO _proof FROM signer.tx_registration_proof WHERE tx_id=NEW.registration_tx_id;
        IF NOT FOUND OR _proof.address IS DISTINCT FROM NEW.address
            OR NOT EXISTS (SELECT 1 FROM signer.role WHERE id=NEW.role_id AND status='ready' AND player_id=_proof.player_id)
            OR NOT EXISTS (SELECT 1 FROM signer.tx WHERE id=NEW.registration_tx_id AND status='pending' AND claim_token IS NULL)
            OR NOT signer.REGISTRATION_CONTEXT_CHECK(NEW.registration_tx_id)
            OR NEW.status IS DISTINCT FROM 'pending'::structs.signer_account_status THEN
            RAISE EXCEPTION 'managed registration link does not match its queued proof and role' USING ERRCODE='55000';
        END IF;
        IF OLD.registration_tx_id IS NULL THEN
            IF OLD.status IS DISTINCT FROM 'generating'::structs.signer_account_status
                OR NEW.id IS DISTINCT FROM OLD.id OR NEW.role_id IS DISTINCT FROM OLD.role_id
                OR (OLD.address IS NOT NULL AND OLD.address IS DISTINCT FROM NEW.address) THEN
                RAISE EXCEPTION 'managed registration requires its original generated account' USING ERRCODE='55000';
            END IF;
        ELSE
            -- Serialize against a worker resolving the preceding request.
            PERFORM 1 FROM signer.tx WHERE id=OLD.registration_tx_id FOR UPDATE;
            SELECT * INTO _previous FROM signer.tx_registration_proof WHERE tx_id=OLD.registration_tx_id;
            IF OLD.status IS DISTINCT FROM 'pending'::structs.signer_account_status
                OR NOT signer.REGISTRATION_FAILED_V022(OLD.registration_tx_id)
                OR (_proof.signing_player_id,_proof.player_id,_proof.address,_proof.pubkey,_proof.permissions,_proof.chain_id,_proof.protocol)
                    IS DISTINCT FROM (_previous.signing_player_id,_previous.player_id,_previous.address,_previous.pubkey,_previous.permissions,_previous.chain_id,_previous.protocol)
                OR _proof.proof_nonce<_previous.proof_nonce OR _proof.source_height<_previous.source_height
                OR _proof.source_height<COALESCE((SELECT (deliver_tx->>'height')::bigint FROM signer.tx_submission WHERE tx_id=_previous.tx_id),0) THEN
                RAISE EXCEPTION 'registration renewal requires a definitive failure and fresh context for the same key and grant' USING ERRCODE='55000';
            END IF;
        END IF;
        INSERT INTO signer.account_registration(tx_id,account_id,previous_tx_id)
        VALUES(NEW.registration_tx_id,NEW.id,OLD.registration_tx_id);
    ELSIF OLD.status='pending' THEN
        IF NEW.status IS DISTINCT FROM 'pending'::structs.signer_account_status
            AND (NEW.status IS DISTINCT FROM 'available'::structs.signer_account_status
                OR NOT signer.ACCOUNT_REGISTRATION_READY_V022(OLD.id,OLD.registration_tx_id)) THEN
            RAISE EXCEPTION 'managed account requires confirmed registration and matching indexed ownership and permissions' USING ERRCODE='55000';
        END IF;
    ELSIF OLD.status IN ('available','signing') THEN
        -- An active key may later lose permission. Current claim authorization
        -- handles that; releasing a terminal submission must still succeed.
        IF NEW.status IS NULL OR NEW.status NOT IN ('available','signing') THEN
            RAISE EXCEPTION 'active managed account cannot return to registration' USING ERRCODE='55000';
        END IF;
    ELSE
        RAISE EXCEPTION 'invalid linked managed account state' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER account_registration_guard_v022 BEFORE INSERT OR UPDATE ON signer.account
    FOR EACH ROW EXECUTE FUNCTION signer.ACCOUNT_REGISTRATION_GUARD_V022();

-- An installation that already ran the old worker must resolve its evidence
-- before this migration can certify that those keys were activated correctly.
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.account WHERE registration_tx_id IS NOT NULL
        AND (status IS NULL OR status NOT IN ('pending','available','signing')
            OR (status IN ('available','signing') AND NOT signer.ACCOUNT_REGISTRATION_READY_V022(id,registration_tx_id)))) THEN
        RAISE EXCEPTION 'existing managed account activation lacks confirmed registration evidence';
    END IF;
END $$;

CREATE FUNCTION signer.ACTIVATE_ACCOUNT_V022(_account_id INTEGER,_registration_tx_id INTEGER)
RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _account signer.account%ROWTYPE;
BEGIN
    SELECT * INTO _account FROM signer.account WHERE id=_account_id FOR UPDATE;
    IF NOT FOUND OR _registration_tx_id IS NULL OR _account.registration_tx_id IS DISTINCT FROM _registration_tx_id THEN
        RAISE EXCEPTION 'activation does not match the current managed registration' USING ERRCODE='55000';
    END IF;
    IF _account.status='pending' THEN
        UPDATE signer.account SET status='available',updated_at=NOW() WHERE id=_account_id RETURNING * INTO _account;
    ELSIF _account.status IS NULL OR _account.status NOT IN ('available','signing') THEN
        RAISE EXCEPTION 'managed account is not awaiting activation' USING ERRCODE='55000';
    END IF;
    RETURN to_jsonb(_account);
END
$BODY$;

CREATE FUNCTION signer.RENEW_ACCOUNT_REGISTRATION_V022(_account_id INTEGER,_previous_tx_id INTEGER,
    _signature CHARACTER VARYING,_proof_context JSONB) RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _account signer.account%ROWTYPE; _previous signer.tx_registration_proof%ROWTYPE; _proof JSONB; _tx JSONB;
BEGIN
    SELECT * INTO _account FROM signer.account WHERE id=_account_id FOR UPDATE;
    IF NOT FOUND OR _previous_tx_id IS NULL THEN
        RAISE EXCEPTION 'renewal requires an existing managed account and preceding request' USING ERRCODE='55000';
    END IF;
    SELECT p.* INTO _previous FROM signer.tx_registration_proof p JOIN signer.account_registration h ON h.tx_id=p.tx_id
        WHERE p.tx_id=_previous_tx_id AND h.account_id=_account_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'preceding registration does not belong to this account' USING ERRCODE='55000'; END IF;
    _proof := signer.REGISTRATION_CONTEXT(_previous.player_id,_previous.address,_previous.pubkey,_signature,_previous.permissions,_proof_context);
    IF _account.registration_tx_id IS DISTINCT FROM _previous_tx_id THEN
        IF EXISTS (SELECT 1 FROM signer.account_registration WHERE tx_id=_account.registration_tx_id
            AND account_id=_account_id AND previous_tx_id=_previous_tx_id)
            AND _proof=signer.REGISTRATION_PROOF_V022(_account.registration_tx_id) THEN
            SELECT to_jsonb(t) INTO _tx FROM signer.tx t WHERE id=_account.registration_tx_id;
            RETURN _tx;
        END IF;
        RAISE EXCEPTION 'managed account already has a different registration attempt' USING ERRCODE='55000';
    END IF;
    PERFORM 1 FROM signer.tx WHERE id=_previous_tx_id FOR UPDATE;
    IF _account.status IS DISTINCT FROM 'pending'::structs.signer_account_status OR NOT signer.REGISTRATION_FAILED_V022(_previous_tx_id) THEN
        RAISE EXCEPTION 'registration cannot be renewed while its outcome is uncertain or successful' USING ERRCODE='55000';
    END IF;
    _tx := signer.CREATE_ADDRESS_REGISTRATION_V022(_previous.signing_player_id,_previous.player_id,_previous.address,
        _previous.pubkey,_signature,_previous.permissions,_proof_context);
    UPDATE signer.account SET registration_tx_id=(_tx->>'id')::integer,updated_at=NOW() WHERE id=_account_id;
    RETURN _tx;
END
$BODY$;

REVOKE ALL ON TABLE signer.tx_unsent_abort,signer.account_registration FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.UNSENT_ABORT_GUARD_V022(),signer.UNSENT_ABORT_PARENT_GUARD_V022(),
    signer.UNSENT_ABORT_AUTHORITY_GUARD_V022(),signer.ACCOUNT_REGISTRATION_IMMUTABLE_V022(),
    signer.ACCOUNT_REGISTRATION_GUARD_V022() FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.REGISTRATION_FAILED_V022(INTEGER),signer.ACCOUNT_REGISTRATION_READY_V022(INTEGER,INTEGER),
    signer.ACTIVATE_ACCOUNT_V022(INTEGER,INTEGER),signer.RENEW_ACCOUNT_REGISTRATION_V022(INTEGER,INTEGER,CHARACTER VARYING,JSONB) FROM PUBLIC;
COMMIT;
