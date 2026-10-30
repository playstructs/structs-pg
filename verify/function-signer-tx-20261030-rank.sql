-- Verify structs-pg:function-signer-tx-20261030-rank on pg
BEGIN;
SELECT 1 / (signer.PERMISSION_ARGUMENT(33554431)='33554431')::int;
SELECT 1 / (to_regprocedure('signer.tx_guild_update_entry_rank(character varying,character varying,bigint)') IS NULL
    AND to_regprocedure('signer.tx_guild_update_entry_rank(character varying,character varying,numeric)') IS NOT NULL)::int;
ROLLBACK;
