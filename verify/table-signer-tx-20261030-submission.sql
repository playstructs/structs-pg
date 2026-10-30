-- Verify structs-pg:table-signer-tx-20261030-submission on pg
BEGIN;
SELECT tx_id,claim_token,account_id,address,chain_id,signed_bytes,tx_hash,account_number,sequence,
    source_height,timeout_height,request,state,check_tx,deliver_tx,local_error,created_at,send_started_at,resolved_at,updated_at
FROM signer.tx_submission WHERE FALSE;
SELECT 1 / (NOT has_function_privilege('public','signer.begin_submission_v022(integer,uuid)','EXECUTE'))::int;
SELECT 1 / (NOT has_function_privilege('public','signer.save_signed_transaction_v022(integer,uuid,bytea,numeric,numeric,numeric,numeric)','EXECUTE'))::int;
ROLLBACK;
