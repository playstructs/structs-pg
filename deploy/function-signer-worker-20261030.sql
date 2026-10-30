-- Deploy structs-pg:function-signer-worker-20261030 to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'worker support requires the coordinated v022-1 signer contract';
    END IF;
END $$;
-- A key request must be fulfillable by the registration contract. Reject
-- undefined permission bits before generating a key, rather than at proof enqueue.
ALTER TABLE signer.account_request ADD CONSTRAINT signer_account_request_defined_permissions CHECK (permissions<=33554431);
CREATE INDEX signer_tx_v022_recovery_idx ON signer.tx(id)
    WHERE contract='v022-1' AND status IN ('claimed','broadcast');
CREATE INDEX signer_account_v022_recovery_idx ON signer.account(id)
    WHERE status IN ('generating','pending');
CREATE OR REPLACE FUNCTION signer.REQUEST_ACCOUNT_V022(_role_id INTEGER,_permissions NUMERIC,
    _max_accounts INTEGER,_request_id UUID,_source TEXT) RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _role signer.role%ROWTYPE; _saved signer.account_request%ROWTYPE; _account_id INTEGER; _context RECORD;
BEGIN
    PERFORM signer.PERMISSION_ARGUMENT(_permissions);
    IF _max_accounts IS NULL OR _max_accounts NOT BETWEEN 1 AND 40 OR _request_id IS NULL OR _source IS NULL OR _source NOT IN ('manual','queue') THEN
        RAISE EXCEPTION 'key request requires an explicit pool limit between 1 and 40, request UUID and source' USING ERRCODE='22023';
    END IF;
    SELECT * INTO _role FROM signer.role WHERE id=_role_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'key request role does not exist' USING ERRCODE='22023'; END IF;
    SELECT * INTO _saved FROM signer.account_request WHERE request_id=_request_id;
    IF FOUND THEN
        IF (_saved.role_id,_saved.permissions,_saved.max_accounts,_saved.source)
            IS DISTINCT FROM (_role_id,_permissions,_max_accounts,_source) THEN
            RAISE EXCEPTION 'key request UUID already identifies a different request' USING ERRCODE='55000';
        END IF;
        RETURN signer.ACCOUNT_REQUEST_V022(_saved.account_id);
    END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _role.status IS DISTINCT FROM 'ready'::structs.signer_role_status OR _role.player_id IS NULL
        OR NOT EXISTS (SELECT 1 FROM structs.player WHERE id=_role.player_id)
        OR _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol IS DISTINCT FROM 'v0.22.0' THEN
        RETURN NULL;
    END IF;
    -- Stop counting at the configured limit instead of scanning the whole pool.
    IF (SELECT count(*) FROM (SELECT 1 FROM signer.account WHERE role_id=_role_id LIMIT _max_accounts) pool)>=_max_accounts THEN
        RETURN NULL;
    END IF;
    INSERT INTO signer.account(role_id,status) VALUES(_role_id,'stub') RETURNING id INTO _account_id;
    INSERT INTO signer.account_request(account_id,request_id,role_id,player_id,permissions,max_accounts,source)
    VALUES(_account_id,_request_id,_role_id,_role.player_id,_permissions,_max_accounts,_source);
    RETURN signer.ACCOUNT_REQUEST_V022(_account_id);
END
$BODY$;

COMMIT;
