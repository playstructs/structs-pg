-- Revert structs-pg:function-signer-tx-20260612-pfp-cr-attributes from pg

BEGIN;

    DROP FUNCTION IF EXISTS signer.tx_player_update_pfp_cr_attributes(CHARACTER VARYING, CHARACTER VARYING);
    DROP FUNCTION IF EXISTS signer.tx_guild_moderate_player_pfp_cr_attributes(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING);

COMMIT;
