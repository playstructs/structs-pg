-- Verify structs-pg:function-signer-tx-20261030-permission-mutation on pg
BEGIN;
SELECT subject_id,operation FROM signer.tx_authority WHERE FALSE;
SELECT 1 / (signer.PERMISSION_MUTATION_CHECK(NULL,'unknown',NULL,NULL,NULL,0) IS FALSE)::int;
SELECT 1 / (NOT has_function_privilege('public','signer.create_transaction_v022(character varying,character varying,structs.signer_tx_module,structs.signer_tx_type,jsonb,jsonb,jsonb)','EXECUTE'))::int;
SELECT 1 / (to_regprocedure('signer.tx_permission_grant_on_address(character varying,character varying,integer)') IS NULL AND to_regprocedure('signer.tx_permission_grant_on_address(character varying,character varying,numeric)') IS NOT NULL)::int;
SELECT 1 / (to_regprocedure('signer.tx_permission_grant_on_object(character varying,character varying,character varying,integer)') IS NULL AND to_regprocedure('signer.tx_permission_grant_on_object(character varying,character varying,character varying,numeric)') IS NOT NULL)::int;
SELECT 1 / (to_regprocedure('signer.tx_permission_revoke_on_address(character varying,character varying,integer)') IS NULL AND to_regprocedure('signer.tx_permission_revoke_on_address(character varying,character varying,numeric)') IS NOT NULL)::int;
SELECT 1 / (to_regprocedure('signer.tx_permission_revoke_on_object(character varying,character varying,character varying,integer)') IS NULL AND to_regprocedure('signer.tx_permission_revoke_on_object(character varying,character varying,character varying,numeric)') IS NOT NULL)::int;
SELECT 1 / (to_regprocedure('signer.tx_permission_set_on_address(character varying,character varying,integer)') IS NULL AND to_regprocedure('signer.tx_permission_set_on_address(character varying,character varying,numeric)') IS NOT NULL)::int;
SELECT 1 / (to_regprocedure('signer.tx_permission_set_on_object(character varying,character varying,character varying,integer)') IS NULL AND to_regprocedure('signer.tx_permission_set_on_object(character varying,character varying,character varying,numeric)') IS NOT NULL)::int;
ROLLBACK;
