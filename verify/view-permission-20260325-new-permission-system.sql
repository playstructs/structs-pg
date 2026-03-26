-- Verify structs-pg:view-permission-20260325-new-permission-system on pg

BEGIN;

    SELECT address, perm_play, perm_admin, perm_update, perm_delete,
           perm_token_transfer, perm_token_infuse, perm_token_migrate, perm_token_defuse,
           perm_source_allocation, perm_guild_membership, perm_substation_connection,
           perm_allocation_connection, perm_guild_token_burn, perm_guild_token_mint,
           perm_guild_endpoint_update, perm_guild_join_constraints_update,
           perm_guild_substation_update, perm_provider_withdraw, perm_provider_open,
           perm_reactor_guild_create, perm_hash_build, perm_hash_mine,
           perm_hash_refine, perm_hash_raid
    FROM view.permission_address WHERE FALSE;

    SELECT object_id, object_type, player_id, perm_play, perm_admin
    FROM view.permission_player WHERE FALSE;

ROLLBACK;
