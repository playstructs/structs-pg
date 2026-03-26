-- Verify structs-pg:function-signer-tx-20260325-permission-overhaul on pg

BEGIN;

    SELECT has_function_privilege('signer.tx_guild_create(character varying, character varying, character varying, character varying)', 'execute');
    SELECT has_function_privilege('signer.tx_guild_update_entry_rank(character varying, bigint)', 'execute');
    SELECT has_function_privilege('signer.tx_permission_guild_rank_set(character varying, character varying, bigint, bigint)', 'execute');
    SELECT has_function_privilege('signer.tx_permission_guild_rank_revoke(character varying, character varying, bigint)', 'execute');
    SELECT has_function_privilege('signer.tx_player_update_guild_rank(character varying, bigint)', 'execute');
    SELECT has_function_privilege('signer.tx_player_send(character varying, character varying, character varying, numeric, character varying)', 'execute');

ROLLBACK;
