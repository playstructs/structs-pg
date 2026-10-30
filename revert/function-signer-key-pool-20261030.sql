-- Revert structs-pg:function-signer-key-pool-20261030 from pg
BEGIN;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM signer.account_pool_source) THEN
    RAISE EXCEPTION 'preserve pool provisioning history before reverting'; END IF; END $$;
DROP FUNCTION signer.REQUEST_POOL_ACCOUNT_V022(UUID,INTEGER,INTEGER,INTEGER,NUMERIC,INTEGER,UUID,JSONB);
DROP TABLE signer.account_pool_source;
DROP FUNCTION signer.POOL_SOURCE_IMMUTABLE_V022();
COMMIT;
