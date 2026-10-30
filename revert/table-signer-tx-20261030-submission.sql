-- Revert structs-pg:table-signer-tx-20261030-submission from pg
BEGIN;
SET LOCAL lock_timeout='5s';
LOCK TABLE signer.tx,signer.account,signer.tx_submission IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM signer.tx_submission) THEN
        RAISE EXCEPTION 'signed history exists; retain its identity and outcomes or restore a verified checkpoint';
    END IF;
END $$;
CREATE OR REPLACE FUNCTION signer.transaction_broadcast_results(transaction_id integer, transaction_output text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
    BEGIN
        UPDATE signer.tx
        SET status      = 'broadcast',
            output      = transaction_output,
            updated_at  = NOW()
        WHERE id = transaction_id;
    END $function$
;
CREATE OR REPLACE FUNCTION signer.transaction_error(transaction_id integer, transaction_error text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
    BEGIN
        UPDATE signer.tx
        SET status      = 'error',
            output      = transaction_error,
            updated_at  = NOW()
        WHERE id = transaction_id;
    END $function$
;
DROP FUNCTION signer.ABORT_UNSENT_TRANSACTION_V022(INTEGER,UUID,TEXT);
DROP FUNCTION signer.RECORD_SUBMISSION_RESULT_V022(INTEGER,UUID,JSONB);
DROP FUNCTION signer.MARK_SUBMISSION_UNKNOWN_V022(INTEGER,UUID,TEXT);
DROP FUNCTION signer.BEGIN_SUBMISSION_V022(INTEGER,UUID);
DROP FUNCTION signer.SAVE_SIGNED_TRANSACTION_V022(INTEGER,UUID,BYTEA,NUMERIC,NUMERIC,NUMERIC,NUMERIC);
DROP FUNCTION signer.SUBMISSION_V022(INTEGER);
DROP TRIGGER submission_account_guard_v022 ON signer.account;
DROP FUNCTION signer.SUBMISSION_ACCOUNT_GUARD_V022();
DROP TRIGGER submission_parent_guard_v022 ON signer.tx;
DROP FUNCTION signer.SUBMISSION_PARENT_GUARD_V022();
DROP TRIGGER submission_authority_guard_v022 ON signer.tx_authority;
DROP FUNCTION signer.SUBMISSION_AUTHORITY_GUARD_V022();
DROP TABLE signer.tx_submission;
DROP FUNCTION signer.SUBMISSION_GUARD_V022();
COMMIT;
