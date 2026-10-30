-- Verify structs-pg:function-signer-proxy-20261030 on pg
BEGIN;
SELECT tx_id,guild_id,address,player_id,proof_nonce,source_height FROM signer.tx_proxy_proof WHERE FALSE;
SELECT 'signer.proxy_context_check_v022(integer,character varying)'::regprocedure;
ROLLBACK;
