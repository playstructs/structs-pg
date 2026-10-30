-- Revert structs-pg:function-signer-account-20261030-registration-lifecycle from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.account,signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.account_registration) OR EXISTS (SELECT 1 FROM signer.tx_unsent_abort) THEN
        RAISE EXCEPTION 'managed registration or unsigned abort history exists; retain the lifecycle or restore a verified checkpoint';
    END IF;
END $$;
DROP FUNCTION signer.RENEW_ACCOUNT_REGISTRATION_V022(INTEGER,INTEGER,CHARACTER VARYING,JSONB);
DROP FUNCTION signer.ACTIVATE_ACCOUNT_V022(INTEGER,INTEGER);
DROP TRIGGER account_registration_guard_v022 ON signer.account;
DROP FUNCTION signer.ACCOUNT_REGISTRATION_GUARD_V022();
DROP FUNCTION signer.ACCOUNT_REGISTRATION_READY_V022(INTEGER,INTEGER);
DROP FUNCTION signer.REGISTRATION_FAILED_V022(INTEGER);
DROP TABLE signer.account_registration;
DROP FUNCTION signer.ACCOUNT_REGISTRATION_IMMUTABLE_V022();
CREATE OR REPLACE FUNCTION signer.abort_unsent_transaction_v022(_tx_id integer, _claim_token uuid, _reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
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
$function$
;
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
DROP TRIGGER unsent_abort_parent_guard_v022 ON signer.tx;
DROP FUNCTION signer.UNSENT_ABORT_PARENT_GUARD_V022();
DROP TRIGGER unsent_abort_authority_guard_v022 ON signer.tx_authority;
DROP FUNCTION signer.UNSENT_ABORT_AUTHORITY_GUARD_V022();
DROP TABLE signer.tx_unsent_abort;
DROP FUNCTION signer.UNSENT_ABORT_GUARD_V022();
COMMIT;
