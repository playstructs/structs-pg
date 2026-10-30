-- Verify structs-pg:function-signer-tx-20261030-wallet on pg
BEGIN;
SELECT 1 / (signer.WALLET_COIN_ARGUMENT(0.000001,'alpha')='1ualpha'
    AND signer.WALLET_COIN_ARGUMENT(9007199254740993,'factory/issuer/token')='9007199254740993factory/issuer/token')::int;
SELECT 1 / (to_regprocedure('signer.tx_infuse(character varying,character varying,character varying,numeric,character varying,character varying)') IS NOT NULL
    AND to_regprocedure('signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,numeric)') IS NOT NULL
    AND to_regprocedure('signer.tx_reactor_cancel_defusion(character varying,character varying,character varying,numeric,character varying,integer)') IS NULL)::int;
ROLLBACK;
