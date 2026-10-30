-- Deploy structs-pg:table-signer-account-20261030-provision-request to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'explicit key provisioning requires the coordinated v022-1 signer contract';
    END IF;
END $$;

-- A request is permission to generate one key, not permission to widen an
-- existing key. Keep the grant even before a registration proof can be made.
CREATE TABLE signer.account_request (
    account_id INTEGER PRIMARY KEY REFERENCES signer.account(id) ON DELETE RESTRICT,
    request_id UUID NOT NULL UNIQUE,
    role_id INTEGER NOT NULL REFERENCES signer.role(id) ON DELETE RESTRICT,
    player_id CHARACTER VARYING NOT NULL,
    permissions NUMERIC NOT NULL CHECK (permissions=trunc(permissions) AND permissions BETWEEN 1 AND 18446744073709551615),
    max_accounts INTEGER NOT NULL CHECK (max_accounts>0),
    source TEXT NOT NULL CHECK (source IN ('manual','queue')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX signer_account_role_pool_idx ON signer.account(role_id,id);

CREATE FUNCTION signer.ACCOUNT_REQUEST_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql AS $BODY$
BEGIN
    IF TG_OP<>'INSERT' THEN
        RAISE EXCEPTION 'key provisioning requests are immutable' USING ERRCODE='55000';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM signer.account a JOIN signer.role r ON r.id=a.role_id
        WHERE a.id=NEW.account_id AND a.role_id=NEW.role_id AND a.status='stub'
          AND a.address IS NULL AND a.registration_tx_id IS NULL
          AND r.status='ready' AND r.player_id=NEW.player_id) THEN
        RAISE EXCEPTION 'key request must match its new account and ready role' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER account_request_guard_v022 BEFORE INSERT OR UPDATE OR DELETE ON signer.account_request
    FOR EACH ROW EXECUTE FUNCTION signer.ACCOUNT_REQUEST_GUARD_V022();

CREATE FUNCTION signer.ACCOUNT_REQUEST_IDENTITY_GUARD_V022() RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $BODY$
DECLARE _request signer.account_request%ROWTYPE;
BEGIN
    SELECT * INTO _request FROM signer.account_request WHERE account_id=OLD.id;
    IF NOT FOUND THEN RETURN NEW; END IF;
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.role_id IS DISTINCT FROM _request.role_id
        OR (OLD.address IS NOT NULL AND NEW.address IS DISTINCT FROM OLD.address) THEN
        RAISE EXCEPTION 'requested key identity cannot be reassigned' USING ERRCODE='55000';
    END IF;
    IF OLD.registration_tx_id IS NULL THEN
        IF (OLD.status='stub' AND (NEW.status IS NULL OR NEW.status NOT IN ('stub','generating') OR NEW.address IS NOT NULL))
            OR (OLD.status='generating' AND (NEW.status IS NULL OR NEW.status NOT IN ('generating','pending')))
            OR (NEW.status='pending' AND NEW.registration_tx_id IS NULL) THEN
            RAISE EXCEPTION 'requested key must pass generation and confirmed registration' USING ERRCODE='55000';
        END IF;
    END IF;
    IF NEW.registration_tx_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM signer.tx_registration_proof p WHERE p.tx_id=NEW.registration_tx_id
          AND p.player_id=_request.player_id AND p.permissions=_request.permissions) THEN
        RAISE EXCEPTION 'registration must preserve the explicitly requested key grant' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER account_request_identity_guard_v022 BEFORE UPDATE ON signer.account
    FOR EACH ROW EXECUTE FUNCTION signer.ACCOUNT_REQUEST_IDENTITY_GUARD_V022();

CREATE FUNCTION signer.ACCOUNT_REQUEST_V022(_account_id INTEGER) RETURNS JSONB LANGUAGE sql STABLE AS $BODY$
    SELECT to_jsonb(a) || jsonb_build_object('request_id',q.request_id,'player_id',q.player_id,
        'permissions',q.permissions::text,'max_accounts',q.max_accounts,'source',q.source)
    FROM signer.account a JOIN signer.account_request q ON q.account_id=a.id WHERE a.id=_account_id;
$BODY$;

-- Both manual requests and the separate queue-pressure manager pass an
-- explicitly configured mask and limit. Lock the role so concurrent requests
-- cannot overshoot the pool; include pending generation/registration and all
-- existing keys in the count. An uncertain client retry reuses its UUID.
CREATE FUNCTION signer.REQUEST_ACCOUNT_V022(_role_id INTEGER,_permissions NUMERIC,
    _max_accounts INTEGER,_request_id UUID,_source TEXT) RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _role signer.role%ROWTYPE; _saved signer.account_request%ROWTYPE; _account_id INTEGER; _context RECORD;
BEGIN
    PERFORM signer.UINT64_ARGUMENT(_permissions,'new key permissions',FALSE);
    IF _max_accounts IS NULL OR _max_accounts<1 OR _request_id IS NULL OR _source IS NULL OR _source NOT IN ('manual','queue') THEN
        RAISE EXCEPTION 'key request requires an explicit pool limit, request UUID and source' USING ERRCODE='22023';
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

CREATE FUNCTION signer.CLAIM_ACCOUNT_V022() RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _account_id INTEGER; _context RECORD;
BEGIN
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol IS DISTINCT FROM 'v0.22.0' THEN RETURN NULL; END IF;
    SELECT a.id INTO _account_id FROM signer.account a
    JOIN signer.account_request q ON q.account_id=a.id AND q.role_id=a.role_id
    JOIN signer.role r ON r.id=q.role_id AND r.player_id=q.player_id AND r.status='ready'
    WHERE a.status='stub' ORDER BY a.created_at,a.id LIMIT 1 FOR UPDATE OF a SKIP LOCKED;
    IF NOT FOUND THEN RETURN NULL; END IF;
    UPDATE signer.account SET status='generating',updated_at=NOW() WHERE id=_account_id;
    RETURN signer.ACCOUNT_REQUEST_V022(_account_id);
END
$BODY$;

REVOKE ALL ON TABLE signer.account_request FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.ACCOUNT_REQUEST_GUARD_V022(),signer.ACCOUNT_REQUEST_IDENTITY_GUARD_V022(),
    signer.ACCOUNT_REQUEST_V022(INTEGER),signer.REQUEST_ACCOUNT_V022(INTEGER,NUMERIC,INTEGER,UUID,TEXT),
    signer.CLAIM_ACCOUNT_V022() FROM PUBLIC;
COMMIT;
