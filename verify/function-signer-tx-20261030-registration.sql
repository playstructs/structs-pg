-- Verify structs-pg:function-signer-tx-20261030-registration on pg
BEGIN;
SELECT tx_id,signing_player_id,player_id,address,pubkey,signature,permissions,chain_id,protocol,proof_nonce,source_height,message
FROM signer.tx_registration_proof WHERE FALSE;
SELECT registration_tx_id FROM signer.account WHERE FALSE;
SELECT 1 / (signer.REGISTRATION_CONTEXT_CHECK(-1) IS FALSE AND signer.ADDRESS_MANAGEMENT_CHECK(-1) IS FALSE)::int;
SELECT 1 / (NOT has_function_privilege('public','signer.create_address_registration_v022(character varying,character varying,character varying,character varying,character varying,numeric,jsonb)','EXECUTE'))::int;
ROLLBACK;
