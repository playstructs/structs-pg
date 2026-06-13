-- Verify structs-pg:function-signer-tx-20260612-pfp-cr-attributes on pg

BEGIN;

    SELECT 'signer.tx_player_update_pfp_cr_attributes(character varying, character varying)'::regprocedure;
    SELECT 'signer.tx_guild_moderate_player_pfp_cr_attributes(character varying, character varying, character varying, character varying)'::regprocedure;

ROLLBACK;
