-- Deploy structs-pg:function-signer-key-pool-20261030 to pg
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE signer.account_pool_source (
    account_id INTEGER PRIMARY KEY REFERENCES signer.account_request(account_id) ON DELETE RESTRICT,
    source_account_id INTEGER NOT NULL REFERENCES signer.account(id) ON DELETE RESTRICT,
    queued_tx_id INTEGER NOT NULL REFERENCES signer.tx(id) ON DELETE RESTRICT,
    source_height BIGINT NOT NULL CHECK (source_height>=3353000),
    source_context JSONB NOT NULL CHECK (jsonb_typeof(source_context)='object')
);
CREATE FUNCTION signer.POOL_SOURCE_IMMUTABLE_V022() RETURNS TRIGGER LANGUAGE plpgsql AS $BODY$
BEGIN RAISE EXCEPTION 'pool key source is immutable' USING ERRCODE='55000'; END
$BODY$;
CREATE TRIGGER pool_source_immutable_v022 BEFORE UPDATE OR DELETE ON signer.account_pool_source
    FOR EACH ROW EXECUTE FUNCTION signer.POOL_SOURCE_IMMUTABLE_V022();

CREATE FUNCTION signer.REQUEST_POOL_ACCOUNT_V022(_inventory_id UUID,_role_id INTEGER,
    _source_account_id INTEGER,_tx_id INTEGER,_permissions NUMERIC,_max_accounts INTEGER,_request_id UUID,_source_context JSONB)
RETURNS JSONB LANGUAGE plpgsql VOLATILE AS $BODY$
DECLARE _request signer.account_request%ROWTYPE; _source signer.account_pool_source%ROWTYPE;
    _role signer.role%ROWTYPE; _context RECORD; _result JSONB;
BEGIN
    IF _max_accounts IS NULL OR _max_accounts NOT BETWEEN 1 AND 40 THEN
        RAISE EXCEPTION 'automatic role pool limit must be between 1 and 40' USING ERRCODE='22023';
    END IF;
    PERFORM signer.PERMISSION_ARGUMENT(_permissions);
    SELECT * INTO _role FROM signer.role WHERE id=_role_id FOR UPDATE;
    IF NOT FOUND THEN RETURN NULL; END IF;
    SELECT * INTO _request FROM signer.account_request WHERE request_id=_request_id;
    IF FOUND THEN
        SELECT * INTO _source FROM signer.account_pool_source WHERE account_id=_request.account_id;
        IF NOT FOUND OR (_request.role_id,_request.permissions,_request.max_accounts,_request.source,
            _source.source_account_id,_source.queued_tx_id,_source.source_context) IS DISTINCT FROM
            (_role_id,_permissions,_max_accounts,'queue',_source_account_id,_tx_id,_source_context) THEN
            RAISE EXCEPTION 'pool retry differs from its original explicit grant and source' USING ERRCODE='55000';
        END IF;
        RETURN signer.ACCOUNT_REQUEST_V022(_request.account_id);
    END IF;
    -- SQL IDs may be reused after a complete database rebuild. A durable
    -- request may only continue against its original player, key and queue row.
    IF _source_context IS NULL OR NOT EXISTS (SELECT 1 FROM signer.tx t
        JOIN signer.account a ON a.id=_source_account_id AND a.role_id=_role_id
        WHERE t.id=_tx_id AND _role.player_id=t.requested_player_id
          AND _source_context=jsonb_build_object('chain_id',t.chain_id,'player_id',t.requested_player_id,
              'address',a.address,'created_at',extract(epoch FROM t.created_at)::text)) THEN RETURN NULL; END IF;
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol IS DISTINCT FROM 'v0.22.0'
        OR _role.status IS DISTINCT FROM 'ready'::structs.signer_role_status THEN RETURN NULL; END IF;
    -- Count all pool states. Only one new registration per role may be in
    -- flight; registrations themselves have a shared player throttle.
    IF EXISTS (SELECT 1 FROM signer.account_request q JOIN signer.account a ON a.id=q.account_id
        WHERE q.role_id=_role_id AND a.status IN ('stub','generating','pending')) THEN RETURN NULL; END IF;
    -- Copy one actual eligible signing key's exact current grant. Never OR
    -- together role grants or guess new permissions from a queue's combined mask.
    IF NOT EXISTS (SELECT 1 FROM signer.tx t
        JOIN signer.AUTHORIZED_ACCOUNTS_V022(_tx_id) eligible ON eligible.account_id=_source_account_id
        JOIN signer.account a ON a.id=eligible.account_id AND a.role_id=_role_id AND a.status='signing'
        JOIN signer.local_key k ON k.address=a.address AND k.inventory_id=_inventory_id
            AND k.present AND k.state='ready' AND k.observed_at>NOW()-INTERVAL '120 seconds'
        JOIN structs.permission p ON p.id='8-' || a.address || '@0' AND p.val=_permissions
        WHERE t.id=_tx_id AND t.status='pending' AND t.contract='v022-1' AND t.requested_player_id=_role.player_id
          AND signer.PERMISSION_CHECK(a.address,_role.player_id,_permissions::integer))
        OR EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(_tx_id) a
            JOIN signer.local_key k ON k.address=a.address AND k.inventory_id=_inventory_id
            WHERE a.status='available' AND k.present AND k.state='ready'
                AND k.observed_at>NOW()-INTERVAL '120 seconds') THEN RETURN NULL; END IF;
    _result := signer.REQUEST_ACCOUNT_V022(_role_id,_permissions,_max_accounts,_request_id,'queue');
    IF _result IS NOT NULL THEN
        INSERT INTO signer.account_pool_source(account_id,source_account_id,queued_tx_id,source_height,source_context)
        VALUES((_result->>'id')::integer,_source_account_id,_tx_id,_context.indexed_height::bigint,_source_context);
    END IF;
    RETURN _result;
END
$BODY$;
REVOKE ALL ON TABLE signer.account_pool_source FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.POOL_SOURCE_IMMUTABLE_V022(),
    signer.REQUEST_POOL_ACCOUNT_V022(UUID,INTEGER,INTEGER,INTEGER,NUMERIC,INTEGER,UUID,JSONB) FROM PUBLIC;
COMMIT;
