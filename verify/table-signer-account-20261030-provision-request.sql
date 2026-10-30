-- Verify structs-pg:table-signer-account-20261030-provision-request on pg
BEGIN;
SELECT account_id,request_id,role_id,player_id,permissions,max_accounts,source,created_at
FROM signer.account_request WHERE FALSE;
SELECT 1 / (signer.ACCOUNT_REQUEST_V022(-1) IS NULL)::int;
SELECT 1 / (count(*)=2)::int FROM pg_trigger WHERE NOT tgisinternal AND tgenabled='O'
    AND tgname IN ('account_request_guard_v022','account_request_identity_guard_v022');
SELECT 1 / (indexdef LIKE '%(role_id, id)%')::int FROM pg_indexes
    WHERE schemaname='signer' AND indexname='signer_account_role_pool_idx';
SELECT 1 / (NOT has_table_privilege('public','signer.account_request','INSERT')
    AND NOT has_function_privilege('public','signer.request_account_v022(integer,numeric,integer,uuid,text)','EXECUTE')
    AND NOT has_function_privilege('public','signer.claim_account_v022()','EXECUTE'))::int;
ROLLBACK;
