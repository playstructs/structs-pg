-- Disposable database only. Reload preserves active work and never grants rights.
\set ON_ERROR_STOP on
BEGIN;
\ir fixtures/v022-signer.sql
DO $$
DECLARE inventory UUID := '10000000-0000-0000-0000-000000000001';
    other_inventory UUID := '10000000-0000-0000-0000-000000000002';
    state TEXT; account_id INTEGER; restored_role_id INTEGER; claimed JSONB; request JSONB;
BEGIN
    PERFORM signer.SYNC_LOCAL_KEYS_V022(inventory,'[{"name":"renamed primary","address":"queuekeya"},{"name":"old retained key","address":"queuerestricted"},{"name":"new key","address":"notregistered"}]');
    IF (SELECT count(*) FROM signer.local_key WHERE inventory_id=inventory)<>3 THEN
        RAISE EXCEPTION 'unregistered local key was not retained in inventory'; END IF;
    state := signer.RECONCILE_LOCAL_KEY_V022(inventory,'notregistered','structstestnet-111',3353000,3353000,'',0,FALSE);
    IF state<>'unregistered' OR EXISTS (SELECT 1 FROM signer.account WHERE address='notregistered') THEN
        RAISE EXCEPTION 'reload activated an unregistered local key'; END IF;
    -- Reproduce a rebuilt database whose chain index has caught up but whose
    -- off-chain TSA roles/accounts disappeared with the old SQL volume.
    DELETE FROM signer.account WHERE role_id=990940;
    DELETE FROM signer.role WHERE id=990940;
    -- Permission owner metadata can predate an address transfer. The approved
    -- address association and current chain observation determine ownership.
    UPDATE structs.permission SET player_id='1-990941' WHERE id='8-queuekeya@0';
    state := signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuekeya','structstestnet-111',3353000,3353000,'1-990940',33554431,FALSE);
    IF state<>'ready' THEN RAISE EXCEPTION 'registered surviving key was not restored'; END IF;
    SELECT id,signer.account.role_id INTO account_id,restored_role_id FROM signer.account WHERE address='queuekeya';
    state := signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuerestricted','structstestnet-111',3353000,3353000,'1-990940',16,FALSE);
    IF state<>'ready' OR (SELECT count(*) FROM signer.role WHERE player_id='1-990940')<>1
        OR (SELECT signer.account.role_id FROM signer.account WHERE address='queuerestricted')<>restored_role_id THEN
        RAISE EXCEPTION 'keys did not reuse one restored role'; END IF;
    PERFORM signer.SYNC_LOCAL_KEYS_V022(other_inventory,'[]');
    PERFORM signer.tx_player_update_name('1-990940','reload test');
    SELECT to_jsonb(t) INTO request FROM signer.tx t ORDER BY id DESC LIMIT 1;
    IF signer.CLAIM_TRANSACTION_V022(other_inventory) IS NOT NULL THEN RAISE EXCEPTION 'worker claimed a nonlocal key'; END IF;
    -- A surviving send journal keeps the key held even if SQL has no tx row.
    PERFORM signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuekeya','structstestnet-111',3353000,3353000,'1-990940',33554431,TRUE);
    IF signer.CLAIM_TRANSACTION_V022(inventory) IS NOT NULL THEN RAISE EXCEPTION 'unresolved send was ignored'; END IF;
    PERFORM signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuekeya','structstestnet-111',3353000,3353000,'1-990940',33554431,FALSE);
    claimed := signer.CLAIM_TRANSACTION_V022(inventory);
    IF claimed IS NULL THEN RAISE EXCEPTION 'eligible local key could not claim'; END IF;
    PERFORM signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuekeya','structstestnet-111',3353000,3353000,'1-990940',33554431,FALSE);
    IF (SELECT status FROM signer.account WHERE id=account_id)<>'signing'
        OR (SELECT claim_token::text FROM signer.tx WHERE id=(request->>'id')::int)<>claimed->'transaction'->>'claim_token' THEN
        RAISE EXCEPTION 'reload reset a live signing claim'; END IF;
    -- A pending managed request must still pass its own registration lifecycle.
    UPDATE signer.account SET status='pending' WHERE address='queuerestricted';
    state := signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuerestricted','structstestnet-111',3353000,3353000,'1-990940',16,FALSE);
    IF state<>'waiting-registration' THEN RAISE EXCEPTION 'reload bypassed pending registration'; END IF;
    state := signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuerestricted','structstestnet-111',3353000,3353000,'1-990940',127,FALSE);
    IF state<>'waiting-index' OR (SELECT val FROM structs.permission WHERE id='8-queuerestricted@0')<>16 THEN
        RAISE EXCEPTION 'reload granted or assumed different permission bits'; END IF;
    UPDATE sync_state.sync_cursor SET status='syncing';
    state := signer.RECONCILE_LOCAL_KEY_V022(inventory,'queuekeya','structstestnet-111',3353000,3353000,'1-990940',33554431,FALSE);
    IF state<>'waiting-index' THEN RAISE EXCEPTION 'reload ignored index readiness'; END IF;
    PERFORM signer.SYNC_LOCAL_KEYS_V022(inventory,'[]');
    IF EXISTS (SELECT 1 FROM signer.local_key WHERE inventory_id=inventory AND present) THEN
        RAISE EXCEPTION 'removed keys remain claimable'; END IF;
    IF (SELECT count(*) FROM signer.account WHERE address IN ('queuekeya','queuerestricted'))<>2 THEN
        RAISE EXCEPTION 'inventory removed historical accounts'; END IF;
END $$;
ROLLBACK;
