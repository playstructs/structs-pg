-- Verify structs-pg:function-signer-tx-20261030-energy on pg
BEGIN;
SELECT 1 / (signer.ENERGY_CONTEXT_CHECK(-1,'absent') IS FALSE)::int;
SELECT 1 / (NOT has_function_privilege('public','signer.create_energy_transaction_v022(character varying,character varying,structs.signer_tx_type,jsonb,jsonb)','EXECUTE'))::int;
SELECT 1 / (signer.ENERGY_REQUEST_VALID('substation-player-migrate','["4-1","1-1,1-2"]','{}') IS TRUE)::int;
SELECT 1 / (signer.ENERGY_REQUEST_VALID('allocation-update','["6-1","18446744073709551616"]','{}') IS FALSE)::int;
ROLLBACK;
