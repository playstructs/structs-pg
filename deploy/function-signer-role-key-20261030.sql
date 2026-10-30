-- Deploy structs-pg:function-signer-role-key-20261030 to pg
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE signer.role_key_request (
    role_id INTEGER PRIMARY KEY REFERENCES signer.role(id) ON DELETE RESTRICT,
    request_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    guild_id VARCHAR NOT NULL,
    username VARCHAR NOT NULL,
    permissions INTEGER NOT NULL CHECK (permissions=33554431),
    address VARCHAR UNIQUE,
    account_id INTEGER UNIQUE REFERENCES signer.account(id) ON DELETE RESTRICT,
    proxy_tx_id INTEGER REFERENCES signer.tx(id) ON DELETE RESTRICT,
    external_requested BOOLEAN NOT NULL DEFAULT FALSE,
    activated BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE signer.role_proxy_attempt (
    tx_id INTEGER PRIMARY KEY REFERENCES signer.tx(id) ON DELETE RESTRICT,
    role_id INTEGER NOT NULL REFERENCES signer.role_key_request(role_id) ON DELETE RESTRICT
);
CREATE TRIGGER role_proxy_attempt_immutable BEFORE UPDATE OR DELETE ON signer.role_proxy_attempt
    FOR EACH ROW EXECUTE FUNCTION signer.POOL_SOURCE_IMMUTABLE_V022();

CREATE FUNCTION signer.ROLE_KEY_IDENTITY_V022() RETURNS TRIGGER LANGUAGE plpgsql AS $BODY$
BEGIN
    IF TG_OP='DELETE' THEN RAISE EXCEPTION 'role key history must be retained' USING ERRCODE='55000'; END IF;
    IF (NEW.role_id,NEW.request_id,NEW.guild_id,NEW.username,NEW.permissions,NEW.created_at) IS DISTINCT FROM
       (OLD.role_id,OLD.request_id,OLD.guild_id,OLD.username,OLD.permissions,OLD.created_at)
       OR (OLD.address IS NOT NULL AND NEW.address IS DISTINCT FROM OLD.address)
       OR (OLD.account_id IS NOT NULL AND NEW.account_id IS DISTINCT FROM OLD.account_id)
       OR (OLD.activated AND NOT NEW.activated) OR (OLD.external_requested AND NOT NEW.external_requested)
       OR (NEW.external_requested AND NEW.proxy_tx_id IS NOT NULL)
       OR (OLD.proxy_tx_id IS NOT NULL AND NEW.proxy_tx_id IS NULL)
       OR (NEW.proxy_tx_id IS DISTINCT FROM OLD.proxy_tx_id AND NOT EXISTS
           (SELECT 1 FROM signer.role_proxy_attempt WHERE tx_id=NEW.proxy_tx_id AND role_id=NEW.role_id)) THEN
        RAISE EXCEPTION 'role key identity and submission history cannot be replaced' USING ERRCODE='55000'; END IF;
    RETURN NEW;
END
$BODY$;
CREATE TRIGGER role_key_identity_v022 BEFORE UPDATE OR DELETE ON signer.role_key_request
    FOR EACH ROW EXECUTE FUNCTION signer.ROLE_KEY_IDENTITY_V022();
REVOKE ALL ON FUNCTION signer.ROLE_KEY_IDENTITY_V022() FROM PUBLIC;

CREATE FUNCTION signer.ROLE_KEY_REQUEST_V022(_role_id INTEGER) RETURNS JSONB LANGUAGE sql STABLE AS $BODY$
    SELECT to_jsonb(q) || jsonb_build_object('role_status',r.status,'player_id',r.player_id,
        'permissions',q.permissions::text) FROM signer.role_key_request q JOIN signer.role r ON r.id=q.role_id
    WHERE q.role_id=_role_id;
$BODY$;

CREATE FUNCTION signer.PREPARE_ROLE_KEY_V022(_role_id INTEGER,_primary_permissions INTEGER)
RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _role signer.role%ROWTYPE; _pending structs.player_internal_pending%ROWTYPE;
    _account signer.account%ROWTYPE; _context RECORD;
BEGIN
    IF _primary_permissions IS DISTINCT FROM 33554431 THEN
        RAISE EXCEPTION 'a new player primary key has the protocol-required full grant' USING ERRCODE='22023'; END IF;
    SELECT * INTO _role FROM signer.role WHERE id=_role_id FOR UPDATE;
    IF NOT FOUND THEN RETURN NULL; END IF;
    IF EXISTS (SELECT 1 FROM signer.role_key_request WHERE role_id=_role_id) THEN
        RETURN signer.ROLE_KEY_REQUEST_V022(_role_id); END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol IS DISTINCT FROM 'v0.22.0'
        OR _role.player_id IS NOT NULL THEN RETURN NULL; END IF;
    SELECT * INTO _pending FROM structs.player_internal_pending WHERE role_id=_role_id;
    IF NOT FOUND OR _pending.guild_id IS DISTINCT FROM _role.guild_id THEN RETURN NULL; END IF;
    IF (SELECT count(*) FROM signer.account WHERE role_id=_role_id)>1 THEN
        RAISE EXCEPTION 'role bootstrap has ambiguous existing accounts' USING ERRCODE='55000'; END IF;
    SELECT * INTO _account FROM signer.account WHERE role_id=_role_id;
    IF FOUND AND (_account.address IS NULL OR _account.status IS DISTINCT FROM 'pending'::structs.signer_account_status
        OR _account.registration_tx_id IS NOT NULL) THEN
        RAISE EXCEPTION 'existing role key cannot be replaced during bootstrap' USING ERRCODE='55000'; END IF;
    INSERT INTO signer.role_key_request(role_id,guild_id,username,permissions,address,account_id,external_requested)
    VALUES(_role_id,_role.guild_id,_pending.username,_primary_permissions,_account.address,_account.id,
        EXISTS(SELECT 1 FROM structs.player_external_pending WHERE primary_address=_account.address));
    IF _role.status='stub' THEN UPDATE signer.role SET status='generating',updated_at=NOW() WHERE id=_role_id; END IF;
    RETURN signer.ROLE_KEY_REQUEST_V022(_role_id);
END
$BODY$;

CREATE FUNCTION signer.BIND_ROLE_KEY_V022(_role_id INTEGER,_request_id UUID,_address VARCHAR,
    _pubkey VARCHAR,_signature VARCHAR) RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _q signer.role_key_request%ROWTYPE; _context RECORD; _tx JSONB; _actor VARCHAR; _id INTEGER;
BEGIN
    SELECT * INTO _q FROM signer.role_key_request WHERE role_id=_role_id FOR UPDATE;
    IF NOT FOUND OR _q.request_id IS DISTINCT FROM _request_id OR _q.activated
        OR (_q.address IS NOT NULL AND _q.address IS DISTINCT FROM _address)
        OR _address IS NULL OR _address !~ '^structs1[ac-hj-np-z02-9]{38}$'
        OR _pubkey IS NULL OR _pubkey !~ '^(02|03)[0-9a-f]{64}$'
        OR _signature IS NULL OR _signature !~ '^[0-9a-f]{128}$' THEN
        RAISE EXCEPTION 'role key identity or proof does not match its request' USING ERRCODE='55000'; END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol IS DISTINCT FROM 'v0.22.0'
        OR EXISTS (SELECT 1 FROM structs.player_address WHERE address=_address AND status='approved') THEN
        RETURN signer.ROLE_KEY_REQUEST_V022(_role_id); END IF;
    UPDATE structs.player_internal_pending SET primary_address=_address
        WHERE role_id=_role_id AND (primary_address IS NULL OR primary_address=_address);
    IF NOT FOUND THEN RAISE EXCEPTION 'pending role identity is missing or changed' USING ERRCODE='55000'; END IF;
    IF _q.account_id IS NULL THEN
        INSERT INTO signer.account(role_id,address,status) VALUES(_role_id,_address,'pending') RETURNING id INTO _id;
        UPDATE signer.role_key_request SET address=_address,account_id=_id WHERE role_id=_role_id;
    END IF;
    IF _q.external_requested THEN RETURN signer.ROLE_KEY_REQUEST_V022(_role_id); END IF;
    IF _q.proxy_tx_id IS NOT NULL THEN
        IF NOT signer.REGISTRATION_FAILED_V022(_q.proxy_tx_id)
            OR _context.indexed_height::bigint<=(SELECT source_height FROM signer.tx_proxy_proof WHERE tx_id=_q.proxy_tx_id) THEN
            RETURN signer.ROLE_KEY_REQUEST_V022(_role_id); END IF;
    END IF;
    SELECT r.player_id INTO _actor FROM signer.role r JOIN structs.player p ON p.id=r.player_id
    WHERE r.status='ready' AND p.guild_id=_q.guild_id AND EXISTS (SELECT 1 FROM signer.account a
        WHERE a.role_id=r.id AND a.status IN ('available','signing') AND signer.PERMISSION_CHECK(a.address,_q.guild_id,512))
        ORDER BY r.id LIMIT 1;
    IF FOUND THEN
        _tx := signer.CREATE_PROXY_TRANSACTION_V022(_actor,_q.guild_id,_address,_pubkey,_signature,'{}');
        INSERT INTO signer.role_proxy_attempt(tx_id,role_id) VALUES((_tx->>'id')::integer,_role_id);
        UPDATE signer.role_key_request SET proxy_tx_id=(_tx->>'id')::integer WHERE role_id=_role_id;
    ELSE
        -- Preserve the existing first-role path: a guild member signs this
        -- public proof through the webapp. Never also queue an internal send.
        INSERT INTO structs.player_external_pending(guild_id,primary_address,pubkey,signature)
        VALUES(_q.guild_id,_address,_pubkey,_signature)
        ON CONFLICT(primary_address) DO NOTHING;
        IF NOT EXISTS (SELECT 1 FROM structs.player_external_pending WHERE primary_address=_address
            AND guild_id=_q.guild_id AND pubkey=_pubkey AND signature=_signature) THEN
            RAISE EXCEPTION 'existing external role proof differs from this request' USING ERRCODE='55000'; END IF;
        UPDATE signer.role_key_request SET external_requested=TRUE WHERE role_id=_role_id;
    END IF;
    UPDATE signer.role SET status='pending',updated_at=NOW() WHERE id=_role_id;
    RETURN signer.ROLE_KEY_REQUEST_V022(_role_id);
END
$BODY$;

CREATE FUNCTION signer.ACTIVATE_ROLE_KEY_V022(_role_id INTEGER,_request_id UUID,_player_id VARCHAR,
    _source_height BIGINT,_observed_height BIGINT) RETURNS BOOLEAN LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _q signer.role_key_request%ROWTYPE; _context RECORD;
BEGIN
    SELECT * INTO _q FROM signer.role_key_request WHERE role_id=_role_id FOR UPDATE;
    IF NOT FOUND OR _q.request_id IS DISTINCT FROM _request_id OR _q.address IS NULL OR _player_id IS NULL
        OR _source_height IS NULL OR _observed_height IS NULL
        OR _observed_height NOT BETWEEN _source_height AND _source_height+5 THEN RETURN FALSE; END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol IS DISTINCT FROM 'v0.22.0'
        OR _context.indexed_height::bigint<>_source_height
        OR NOT EXISTS (SELECT 1 FROM signer.role r JOIN structs.player p ON p.id=r.player_id
            JOIN structs.player_address pa ON pa.address=_q.address AND pa.player_id=p.id AND pa.status='approved'
            JOIN structs.permission mask ON mask.id='8-' || pa.address || '@0' AND mask.val=_q.permissions
            WHERE r.id=_role_id AND r.status='ready' AND p.id=_player_id
                AND p.primary_address=_q.address AND p.guild_id=_q.guild_id)
        OR (_q.proxy_tx_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM signer.tx_submission s
            WHERE s.tx_id=_q.proxy_tx_id AND s.state='committed' AND s.deliver_tx->>'code'='0'
                AND (s.deliver_tx->>'height')::bigint<=_source_height)) THEN RETURN FALSE; END IF;
    UPDATE signer.account SET status='available',updated_at=NOW()
        WHERE id=_q.account_id AND role_id=_role_id AND address=_q.address AND status='pending' AND registration_tx_id IS NULL;
    IF FOUND THEN UPDATE signer.role_key_request SET activated=TRUE WHERE role_id=_role_id; RETURN TRUE; END IF;
    RETURN _q.activated;
END
$BODY$;
REVOKE ALL ON TABLE signer.role_key_request,signer.role_proxy_attempt FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.ROLE_KEY_REQUEST_V022(INTEGER),signer.PREPARE_ROLE_KEY_V022(INTEGER,INTEGER),
    signer.BIND_ROLE_KEY_V022(INTEGER,UUID,VARCHAR,VARCHAR,VARCHAR),
    signer.ACTIVATE_ROLE_KEY_V022(INTEGER,UUID,VARCHAR,BIGINT,BIGINT) FROM PUBLIC;
COMMIT;
