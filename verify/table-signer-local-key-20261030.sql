-- Verify structs-pg:table-signer-local-key-20261030 on pg
BEGIN;
SELECT inventory_id,address,key_name,present,state,chain_id,player_id,permissions,source_height,observed_height,observed_at,seen_at FROM signer.local_key WHERE FALSE;
SELECT 1/(count(*)=3)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='signer' AND (p.proname IN ('sync_local_keys_v022','reconcile_local_key_v022')
 OR (p.proname='claim_transaction_v022' AND p.pronargs=1));
ROLLBACK;
