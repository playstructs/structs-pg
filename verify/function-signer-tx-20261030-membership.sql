-- Verify structs-pg:function-signer-tx-20261030-membership on pg
BEGIN;
SELECT 1 / (signer.MEMBERSHIP_CONTEXT_CHECK(-1,'absent') IS FALSE)::int;
SELECT 1 / (NOT has_function_privilege('public','signer.create_membership_transaction_v022(character varying,structs.signer_tx_type,character varying,character varying,character varying,character varying[])','EXECUTE'))::int;
SELECT 1 / (signer.MEMBERSHIP_ARGUMENTS('guild-membership-join','0-1','1-1',NULL,NULL)
    ='{"args":["0-1",""],"flags":{"player-id":"1-1"}}'::jsonb)::int;
ROLLBACK;
