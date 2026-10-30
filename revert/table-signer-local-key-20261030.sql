-- Revert structs-pg:table-signer-local-key-20261030 from pg
BEGIN;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.local_key) THEN
        RAISE EXCEPTION 'preserve the public key inventory before reverting local recovery';
    END IF;
END $$;
DROP FUNCTION signer.CLAIM_TRANSACTION_V022(UUID);
DROP FUNCTION signer.RECONCILE_LOCAL_KEY_V022(UUID,VARCHAR,TEXT,BIGINT,BIGINT,VARCHAR,NUMERIC,BOOLEAN);
DROP FUNCTION signer.SYNC_LOCAL_KEYS_V022(UUID,JSONB);
DROP TABLE signer.local_key;
COMMIT;
