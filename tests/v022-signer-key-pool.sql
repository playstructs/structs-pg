\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
-- A legacy role can be above the old total cap without useful capacity.
INSERT INTO signer.account(id,role_id,address,status)
SELECT 991000+n,990940,'legacy-limited-' || n,'available' FROM generate_series(1,102) n;
INSERT INTO structs.permission(id,object_type,object_index,object_id,player_id,val)
SELECT '8-legacy-limited-' || n || '@0','address','legacy-limited-' || n,
    '1-990940','1-990940',127 FROM generate_series(1,102) n;
INSERT INTO signer.account(id,role_id,status) VALUES (992001,990940,'pending'),(992002,990940,'pending');
DO $$
DECLARE inventory UUID := '20000000-0000-0000-0000-000000000001';
    request_id UUID := '20000000-0000-0000-0000-000000000002';
    claim JSONB; pending_id INTEGER; request JSONB; retry JSONB; context JSONB;
BEGIN
    IF signer.REQUEST_ACCOUNT_V022(990940,33554431,40,gen_random_uuid(),'manual') IS NOT NULL THEN
        RAISE EXCEPTION 'manual request bypassed total role cap'; END IF;
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
    IF signer.REQUEST_ACCOUNT_V022(990940,33554431,2,gen_random_uuid(),'queue') IS NOT NULL THEN
        RAISE EXCEPTION 'matching unfinished registration was not counted toward capacity'; END IF;
    IF signer.REQUEST_ACCOUNT_V022(990940,512,2,gen_random_uuid(),'queue') IS NOT NULL THEN
        RAISE EXCEPTION 'superset grants were not counted toward capacity'; END IF;
    IF signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,40,gen_random_uuid(),context) IS NOT NULL THEN
        RAISE EXCEPTION 'a second registration was created while one was pending'; END IF;
    IF (SELECT count(*) FROM signer.account_pool_source)<>1 THEN RAISE EXCEPTION 'pool grant source audit missing'; END IF;
    BEGIN
        PERFORM signer.REQUEST_POOL_ACCOUNT_V022(inventory,990940,990940,pending_id,33554431,41,gen_random_uuid(),context);
        RAISE EXCEPTION 'pool accepted more than forty keys';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
ROLLBACK;
