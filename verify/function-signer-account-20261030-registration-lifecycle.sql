-- Verify structs-pg:function-signer-account-20261030-registration-lifecycle on pg
BEGIN;
SELECT tx_id,claim_token,account_id,reason,created_at FROM signer.tx_unsent_abort WHERE FALSE;
SELECT tx_id,account_id,previous_tx_id,created_at FROM signer.account_registration WHERE FALSE;
SELECT 1 / (signer.REGISTRATION_FAILED_V022(-1) IS FALSE
    AND signer.ACCOUNT_REGISTRATION_READY_V022(-1,-1) IS FALSE)::int;
SELECT 1 / (count(*)=5)::int FROM pg_trigger WHERE NOT tgisinternal AND tgenabled='O' AND tgname IN (
    'account_registration_guard_v022','account_registration_immutable_v022','unsent_abort_guard_v022',
    'unsent_abort_parent_guard_v022','unsent_abort_authority_guard_v022');
SELECT 1 / (NOT has_function_privilege('public','signer.activate_account_v022(integer,integer)','EXECUTE')
    AND NOT has_function_privilege('public','signer.renew_account_registration_v022(integer,integer,character varying,jsonb)','EXECUTE')
    AND NOT has_table_privilege('public','signer.tx_unsent_abort','SELECT')
    AND NOT has_table_privilege('public','signer.account_registration','INSERT'))::int;
ROLLBACK;
