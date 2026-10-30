\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
DO $$
DECLARE inventory UUID := '20000000-0000-0000-0000-000000000001';
    request_id UUID := '20000000-0000-0000-0000-000000000002';
    claim JSONB; pending_id INTEGER; request JSONB; retry JSONB; context JSONB;
BEGIN
    PERFORM signer.SYNC_LOCAL_KEYS_V022(inventory,'[{"name":"busy","address":"queuekeya"},{"name":"limited","address":"queuerestricted"}]');
    PERFORM signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuekeya','structstestnet-111',3353000,3353000,'1-990940',33554431,FALSE);
    PERFORM signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuerestricted','structstestnet-111',3353000,3353000,'1-990940',16,FALSE);
    PERFORM signer.tx_player_update_name('1-990940','first request');
    PERFORM signer.tx_player_update_name('1-990940','queued request');
    SELECT max(id) INTO pending_id FROM signer.tx;
    SELECT jsonb_build_object('chain_id',chain_id,'player_id',requested_player_id,
        'address','queuekeya','created_at',extract(epoch FROM created_at)::text) INTO context FROM signer.tx WHERE id=pending_id;
    IF signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,40,request_id,context) IS NOT NULL THEN
        RAISE EXCEPTION 'available key triggered unnecessary pool growth'; END IF;
    claim := signer.CLAIM_TRANSACTION_V022(inventory);
    IF claim IS NULL THEN RAISE EXCEPTION 'test key did not become busy'; END IF;
    IF signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,127,40,request_id,context) IS NOT NULL THEN
        RAISE EXCEPTION 'pool guessed a grant instead of copying its eligible key'; END IF;
    IF signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990942,pending_id,16,40,request_id,context) IS NOT NULL THEN
        RAISE EXCEPTION 'ineligible restricted key triggered pool growth'; END IF;
    IF signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,40,request_id,
        context || '{"address":"key-from-destroyed-database"}'::jsonb) IS NOT NULL THEN
        RAISE EXCEPTION 'pool request survived reused SQL identities'; END IF;
    request := signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,40,request_id,context);
    IF request IS NULL OR request->>'permissions'<>'33554431' THEN RAISE EXCEPTION 'busy eligible role did not grow'; END IF;
    retry := signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,40,request_id,context);
    IF request IS DISTINCT FROM retry THEN RAISE EXCEPTION 'uncertain pool request retry duplicated its key'; END IF;
    IF signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,40,gen_random_uuid(),context) IS NOT NULL THEN
        RAISE EXCEPTION 'a second registration was created while one was pending'; END IF;
    IF (SELECT count(*) FROM signer.account_pool_source)<>1 THEN RAISE EXCEPTION 'pool grant source audit missing'; END IF;
    BEGIN
        PERFORM signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,41,gen_random_uuid(),context);
        RAISE EXCEPTION 'pool accepted more than forty keys';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
ROLLBACK;
