-- Revert structs-pg:function-signer-key-pool-20261103-priority
BEGIN;
SET LOCAL lock_timeout='5s';
-- Only the current registration of an audited automatic pool request gets priority.
-- Eligibility, inventory freshness, row locking and FIFO within each class stay intact.
CREATE OR REPLACE FUNCTION signer.CLAIM_TRANSACTION_V022(_inventory_id UUID) RETURNS JSONB AS
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
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp;

COMMIT;
