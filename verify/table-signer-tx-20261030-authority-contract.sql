-- Verify structs-pg:table-signer-tx-20261030-authority-contract on pg
BEGIN;
SELECT contract,requested_player_id,chain_id,prepared_height,claim_token FROM signer.tx WHERE FALSE;
SELECT tx_id,check_type,object_id,permission FROM signer.tx_authority WHERE FALSE;
SELECT account_id,address,status FROM signer.AUTHORIZED_ACCOUNTS_V022(-1);
SELECT 1 / (NOT signer.TRANSACTION_AUTHORITY_CHECK(NULL,NULL,'unknown',NULL,1))::int;
SELECT 1 / (NOT has_function_privilege('public','signer.claim_transaction_v022()','EXECUTE'))::int;
ROLLBACK;
