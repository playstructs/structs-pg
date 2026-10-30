-- Verify structs-pg:function-signer-key-pool-20261030 on pg
BEGIN;
SELECT account_id,source_account_id,queued_tx_id,source_height FROM signer.account_pool_source WHERE FALSE;
SELECT 'signer.request_pool_account_v022(uuid,integer,integer,integer,numeric,integer,uuid,jsonb)'::regprocedure;
ROLLBACK;
