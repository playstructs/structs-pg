-- Verify structs-pg:function-signer-tx-20261030-gameplay on pg
BEGIN;
SELECT 1 / (signer.GAMEPLAY_ID_ARGUMENT('5-18446744073709551615','5')='5-18446744073709551615')::int;
SELECT 1 / (signer.GAMEPLAY_TARGETS_ARGUMENT('5-1,5-1')='5-1,5-1')::int;
SELECT 'signer.tx_struct_build_initiate(character varying,numeric,character varying,numeric)'::regprocedure;
SELECT 'signer.tx_struct_move(character varying,character varying,character varying,character varying,numeric)'::regprocedure;
SELECT 1 / (signer.REGISTERED_REACTOR_CHECK(-1,'absent') IS FALSE)::int;
ROLLBACK;
