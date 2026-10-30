-- Verify structs-pg:function-signer-tx-20261030-cosmetic on pg
BEGIN;
SELECT 1 / (signer.COSMETIC_CONTEXT_CHECK(-1) IS FALSE)::int;
SELECT 1 / (NOT has_function_privilege('public','signer.create_cosmetic_transaction_v022(character varying,structs.signer_tx_type,character varying,character varying,character varying)','EXECUTE'))::int;
SELECT 1 / (signer.STATION_CONNECTION_CHECK('absent','absent') IS FALSE)::int;
ROLLBACK;
