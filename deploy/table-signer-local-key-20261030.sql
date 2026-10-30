-- Deploy structs-pg:table-signer-local-key-20261030 to pg
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
    IF current_setting('structs.signer_contract',TRUE) IS DISTINCT FROM 'v022-1' THEN
        RAISE EXCEPTION 'local key recovery requires the coordinated v022-1 signer contract';
    END IF;
END $$;
-- Inventory contains public identifiers only. The keyring, recovery phrases and
-- send journal stay on the TSA volume. Unknown/unregistered keys remain visible.
CREATE TABLE signer.local_key (
    inventory_id UUID NOT NULL,
    address VARCHAR NOT NULL CHECK (length(address) BETWEEN 1 AND 128),
    key_name TEXT NOT NULL CHECK (length(key_name) BETWEEN 1 AND 256),
    present BOOLEAN NOT NULL DEFAULT TRUE,
    state TEXT NOT NULL DEFAULT 'unverified' CHECK (state IN
        ('unverified','unregistered','held','waiting-index','waiting-registration','conflict','ready')),
    chain_id TEXT,
    player_id VARCHAR,
    permissions NUMERIC CHECK (permissions=trunc(permissions) AND permissions BETWEEN 0 AND 33554431),
    source_height BIGINT,
    observed_height BIGINT,
    observed_at TIMESTAMPTZ,
    seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY(inventory_id,address)
);

CREATE FUNCTION signer.SYNC_LOCAL_KEYS_V022(_inventory_id UUID,_keys JSONB) RETURNS VOID
LANGUAGE plpgsql VOLATILE AS $BODY$
BEGIN
    IF _inventory_id IS NULL OR _keys IS NULL OR jsonb_typeof(_keys)<>'array' THEN
        RAISE EXCEPTION 'local key inventory requires an identity and key array' USING ERRCODE='22023';
    END IF;
    IF jsonb_array_length(_keys)>10000 OR EXISTS (SELECT 1 FROM jsonb_array_elements(_keys) k
        WHERE jsonb_typeof(k)<>'object' OR NOT k ?& ARRAY['name','address']
            OR k-ARRAY['name','address']<>'{}'::jsonb OR jsonb_typeof(k->'name')<>'string'
            OR jsonb_typeof(k->'address')<>'string' OR length(k->>'name') NOT BETWEEN 1 AND 256
            OR length(k->>'address') NOT BETWEEN 1 AND 128)
        OR (SELECT count(*) FROM jsonb_array_elements(_keys))<>
           (SELECT count(DISTINCT k->>'address') FROM jsonb_array_elements(_keys) k) THEN
        RAISE EXCEPTION 'invalid local key inventory' USING ERRCODE='22023';
    END IF;
    -- Serialize complete snapshots from processes sharing this volume identity.
    PERFORM pg_advisory_xact_lock(hashtextextended('tsa-inventory:' || _inventory_id::text,0));
    UPDATE signer.local_key SET present=FALSE WHERE inventory_id=_inventory_id;
    INSERT INTO signer.local_key(inventory_id,address,key_name)
        SELECT _inventory_id,k->>'address',k->>'name' FROM jsonb_array_elements(_keys) k
    ON CONFLICT(inventory_id,address) DO UPDATE SET key_name=EXCLUDED.key_name,present=TRUE,seen_at=NOW();
END
$BODY$;

CREATE FUNCTION signer.RECONCILE_LOCAL_KEY_V022(_inventory_id UUID,_address VARCHAR,
    _chain_id TEXT,_source_height BIGINT,_observed_height BIGINT,_player_id VARCHAR,
    _permissions NUMERIC,_held BOOLEAN) RETURNS TEXT LANGUAGE plpgsql VOLATILE AS $BODY$
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

CREATE FUNCTION signer.CLAIM_TRANSACTION_V022(_inventory_id UUID) RETURNS JSONB AS
$BODY$
DECLARE
    _context RECORD;
    _tx signer.tx%ROWTYPE;
    _account signer.account%ROWTYPE;
    _visited INTEGER[] := ARRAY[]::INTEGER[];
    _attempt INTEGER;
BEGIN
    SELECT * INTO _context FROM structs.api_readiness(ARRAY[]::TEXT[]);
    IF _context.transaction_ready IS DISTINCT FROM TRUE OR _context.protocol<>'v0.22.0' THEN RETURN NULL; END IF;
    -- Another worker can lock a key after eligibility was read. Skip that
    -- request and consider a bounded number of other ready requests this call.
    FOR _attempt IN 1..32 LOOP
        -- Select one row at a time: a cursor loop may prefetch/lock other
        -- players' requests before returning its first successful claim.
        SELECT t.* INTO _tx FROM signer.tx t
        WHERE t.status='pending' AND t.contract='v022-1' AND t.id<>ALL(_visited)
          AND t.chain_id=_context.chain_id AND t.prepared_height<=_context.indexed_height::bigint
          AND EXISTS (SELECT 1 FROM signer.AUTHORIZED_ACCOUNTS_V022(t.id) a JOIN signer.local_key k ON k.address=a.address
              WHERE a.status='available' AND k.inventory_id=_inventory_id AND k.present AND k.state='ready'
                AND k.observed_at>NOW()-INTERVAL '120 seconds')
        ORDER BY t.updated_at,t.id LIMIT 1 FOR UPDATE OF t SKIP LOCKED;
        IF NOT FOUND THEN RETURN NULL; END IF;
        _visited := array_append(_visited,_tx.id);
        SELECT a.* INTO _account FROM signer.account a
        JOIN signer.AUTHORIZED_ACCOUNTS_V022(_tx.id) eligible ON eligible.account_id=a.id
        JOIN signer.local_key k ON k.address=a.address AND k.inventory_id=_inventory_id
        WHERE a.status='available' AND k.present AND k.state='ready'
            AND k.observed_at>NOW()-INTERVAL '120 seconds' ORDER BY a.updated_at,a.id
        LIMIT 1 FOR UPDATE OF a SKIP LOCKED;
        IF NOT FOUND THEN CONTINUE; END IF;
        UPDATE signer.account SET status='signing',updated_at=NOW() WHERE id=_account.id RETURNING * INTO _account;
        UPDATE signer.tx SET status='claimed',account_id=_account.id,claim_token=gen_random_uuid(),updated_at=NOW()
        WHERE id=_tx.id RETURNING * INTO _tx;
        RETURN jsonb_build_object('transaction',to_jsonb(_tx),'account',to_jsonb(_account));
    END LOOP;
    RETURN NULL;
END
$BODY$
LANGUAGE plpgsql VOLATILE;
REVOKE ALL ON FUNCTION signer.CLAIM_TRANSACTION_V022(UUID) FROM PUBLIC;

REVOKE ALL ON TABLE signer.local_key FROM PUBLIC;
REVOKE ALL ON FUNCTION signer.SYNC_LOCAL_KEYS_V022(UUID,JSONB),
    signer.RECONCILE_LOCAL_KEY_V022(UUID,VARCHAR,TEXT,BIGINT,BIGINT,VARCHAR,NUMERIC,BOOLEAN) FROM PUBLIC;
COMMIT;
