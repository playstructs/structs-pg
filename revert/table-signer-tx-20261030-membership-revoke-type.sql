-- Revert structs-pg:table-signer-tx-20261030-membership-revoke-type from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx WHERE contract='v022-1' AND command='guild-membership-invite-revoke') THEN
        RAISE EXCEPTION 'versioned invitation revocations exist; retain their command contract';
    END IF;
END $$;
-- PostgreSQL enum labels are append-only. Match the repository's enum-change
-- convention: leave this unused literal in place rather than rebuilding the
-- type and every table/function that depends on it. Deploy is idempotent so an
-- empty revert/redeploy remains supported. No request is rewritten or removed.
COMMIT;
