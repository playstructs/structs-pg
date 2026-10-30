-- Verify structs-pg:function-signer-tx-20261030-provider-agreement on pg
BEGIN;
SELECT 1 / (signer.UINT64_ARGUMENT(18446744073709551615,'test')='18446744073709551615'
    AND signer.COIN_ARGUMENT(9007199254740993,'ualpha')='9007199254740993ualpha'
    AND signer.PENALTY_ARGUMENT(0.123456789012345678)='0.123456789012345678')::int;
SELECT 1 / (to_regprocedure('signer.tx_agreement_open(character varying,character varying,numeric,numeric,character varying)') IS NOT NULL
    AND to_regprocedure('signer.tx_provider_create(character varying,character varying,character varying,numeric,character varying,numeric,numeric,numeric,numeric,numeric,numeric,character varying)') IS NOT NULL)::int;
ROLLBACK;
