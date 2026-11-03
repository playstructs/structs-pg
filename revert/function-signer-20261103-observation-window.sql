-- Revert structs-pg:function-signer-20261103-observation-window
BEGIN;
SET LOCAL lock_timeout='5s';
-- Tolerate bounded index advancement during observation/signing. Current
-- authority and readiness checks remain mandatory; send still needs preflight.
CREATE OR REPLACE FUNCTION signer.SAVE_SIGNED_TRANSACTION_V022(_tx_id INTEGER,_claim_token UUID,_signed_bytes BYTEA,
    _account_number NUMERIC,_sequence NUMERIC,_source_height NUMERIC,_timeout_height NUMERIC)
RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
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
$BODY$;


CREATE OR REPLACE FUNCTION signer.RECONCILE_LOCAL_KEY_V022(_inventory_id UUID,_address VARCHAR,
    _chain_id TEXT,_source_height BIGINT,_observed_height BIGINT,_player_id VARCHAR,
    _permissions NUMERIC,_held BOOLEAN) RETURNS TEXT LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _context RECORD; _account signer.account%ROWTYPE; _role_id INTEGER; _state TEXT;
BEGIN
    IF _chain_id IS DISTINCT FROM 'structstestnet-111' OR _source_height IS NULL OR _source_height<3353000
        OR _observed_height IS NULL OR _observed_height<_source_height OR _observed_height>_source_height+5
        OR _player_id IS NULL OR (_player_id<>'' AND _player_id !~ '^1-[1-9][0-9]*$')
        OR _permissions IS NULL OR _permissions<>trunc(_permissions) OR _permissions NOT BETWEEN 0 AND 33554431
        OR _held IS NULL THEN
        RAISE EXCEPTION 'invalid current local key observation' USING ERRCODE='22023';
    END IF;
    PERFORM 1 FROM signer.local_key WHERE inventory_id=_inventory_id AND address=_address AND present FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'key is absent from local inventory' USING ERRCODE='55000'; END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    _state := CASE WHEN _held THEN 'held' WHEN _player_id='' OR _permissions=0 THEN 'unregistered'
        ELSE 'waiting-index' END;
    IF NOT _held AND _player_id<>'' AND _permissions>0
        AND _context.transaction_ready AND _context.chain_id=_chain_id AND _context.protocol='v0.22.0'
        AND _context.indexed_height::bigint=_source_height
        AND EXISTS (SELECT 1 FROM structs.player_address pa JOIN structs.permission p
            ON p.id='8-' || pa.address || '@0' AND p.val=_permissions
            WHERE pa.address=_address AND pa.status='approved' AND pa.player_id=_player_id)
        AND NOT EXISTS (SELECT 1 FROM structs.vault WHERE address=_address) THEN
        -- Different surviving keys may all restore the same missing role.
        PERFORM pg_advisory_xact_lock(hashtextextended('tsa-player:' || _player_id,0));
        SELECT * INTO _account FROM signer.account WHERE address=_address FOR UPDATE;
        IF FOUND THEN
            -- Never reset a lease, detach registration evidence, or overwrite a
            -- historical role because an address has since changed ownership.
            IF NOT EXISTS (SELECT 1 FROM signer.role WHERE id=_account.role_id AND status='ready' AND player_id=_player_id) THEN
                _state := 'conflict';
            ELSIF _account.status IN ('available','signing') THEN _state := 'ready';
            ELSE _state := 'waiting-registration'; END IF;
        ELSE
            SELECT id INTO _role_id FROM signer.role WHERE player_id=_player_id AND status='ready' ORDER BY id LIMIT 1;
            IF NOT FOUND THEN
                IF EXISTS (SELECT 1 FROM signer.role WHERE player_id=_player_id) THEN
                    _state := 'conflict';
                ELSE
                    INSERT INTO signer.role(player_id,guild_id,status)
                        SELECT id,guild_id,'ready' FROM structs.player WHERE id=_player_id RETURNING id INTO _role_id;
                END IF;
            END IF;
            IF _role_id IS NOT NULL THEN
                INSERT INTO signer.account(role_id,address,status) VALUES(_role_id,_address,'available')
                    ON CONFLICT(address) DO NOTHING;
                _state := 'ready';
            END IF;
        END IF;
    END IF;
    UPDATE signer.local_key SET state=_state,chain_id=_chain_id,player_id=_player_id,permissions=_permissions,
        source_height=_source_height,observed_height=_observed_height,observed_at=NOW()
        WHERE inventory_id=_inventory_id AND address=_address;
    RETURN _state;
END
$BODY$;


COMMIT;
