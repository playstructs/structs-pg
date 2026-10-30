-- Verify structs-pg:function-signer-role-key-20261030 on pg
BEGIN;
SELECT role_id,request_id,guild_id,username,permissions,address,account_id,proxy_tx_id,external_requested,activated FROM signer.role_key_request WHERE FALSE;
SELECT tx_id,role_id FROM signer.role_proxy_attempt WHERE FALSE;
SELECT 'signer.activate_role_key_v022(integer,uuid,character varying,bigint,bigint)'::regprocedure;
ROLLBACK;
