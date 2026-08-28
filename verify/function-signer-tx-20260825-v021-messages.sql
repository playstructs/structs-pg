-- Verify structs-pg:function-signer-tx-20260825-v021-messages on pg

BEGIN;

    SELECT 'signer.tx_guild_bank_convert(character varying, character varying, numeric, numeric)'::regprocedure;
    SELECT 'signer.tx_guild_bank_convert_token(character varying, numeric, character varying, character varying, numeric)'::regprocedure;
    SELECT 'signer.tx_guild_update_bank_convert_in_fee(character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_update_bank_convert_out_fee(character varying, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_reactor_restart(character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_create_charter(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying)'::regprocedure;

    SELECT 'signer.tx_guild_bank_redeem(character varying, numeric, character varying, numeric)'::regprocedure;
    SELECT 'signer.tx_guild_bank_mint(character varying, numeric, numeric, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_bank_confiscate_and_burn(character varying, numeric, character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_update_entry_rank(character varying, character varying, bigint)'::regprocedure;
    SELECT 'signer.tx_player_update_guild_rank(character varying, bigint, character varying)'::regprocedure;

    -- Entitlement-path guild-create is unchanged.
    SELECT 'signer.tx_guild_create(character varying, character varying, character varying, character varying)'::regprocedure;

ROLLBACK;
