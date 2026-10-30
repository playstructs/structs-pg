-- Revert structs-pg:table-signer-account-20261030-provision-request from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.account,signer.account_request IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.account_request) THEN
        RAISE EXCEPTION 'key provisioning requests exist; preserve their grants and identities or restore a verified checkpoint';
    END IF;
END $$;
DROP FUNCTION signer.CLAIM_ACCOUNT_V022();
DROP FUNCTION signer.REQUEST_ACCOUNT_V022(INTEGER,NUMERIC,INTEGER,UUID,TEXT);
DROP FUNCTION signer.ACCOUNT_REQUEST_V022(INTEGER);
DROP TRIGGER account_request_identity_guard_v022 ON signer.account;
DROP FUNCTION signer.ACCOUNT_REQUEST_IDENTITY_GUARD_V022();
DROP TABLE signer.account_request;
DROP FUNCTION signer.ACCOUNT_REQUEST_GUARD_V022();
DROP INDEX signer.signer_account_role_pool_idx;
COMMIT;
