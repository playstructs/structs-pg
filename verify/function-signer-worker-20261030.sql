-- Verify structs-pg:function-signer-worker-20261030 on pg
BEGIN;
SELECT 1 / (count(*)=2)::int FROM pg_indexes WHERE schemaname='signer'
    AND indexname IN ('signer_tx_v022_recovery_idx','signer_account_v022_recovery_idx');
SELECT 1 / (count(*)=1)::int FROM pg_constraint WHERE conrelid='signer.account_request'::regclass
    AND conname='signer_account_request_defined_permissions' AND convalidated;
DO $$ BEGIN
    BEGIN
        PERFORM signer.REQUEST_ACCOUNT_V022(-1,33554432,1,gen_random_uuid(),'queue');
    EXCEPTION WHEN invalid_parameter_value THEN
        IF SQLERRM='permission contains undefined bits' THEN RETURN; END IF;
        RAISE;
    END;
    RAISE EXCEPTION 'worker provisioning accepted undefined permission bits';
END $$;
ROLLBACK;
