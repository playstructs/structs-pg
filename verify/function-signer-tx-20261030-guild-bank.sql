-- Verify structs-pg:function-signer-tx-20261030-guild-bank on pg
BEGIN;
SELECT 1 / (signer.BANK_FEE_ARGUMENT('0.999999999999999999')='0.999999999999999999')::int;
SELECT 1 / (signer.BANK_FEE_ARGUMENT('0.0000')='0')::int;
SELECT 1 / (count(*)=7)::int FROM pg_proc WHERE pronamespace='signer'::regnamespace
    AND (proname LIKE 'tx_guild_bank_%' OR proname LIKE 'tx_guild_update_bank_%');
ROLLBACK;
