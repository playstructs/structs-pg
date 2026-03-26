-- Deploy structs-pg:view-permission-20260325-new-permission-system to pg

BEGIN;

/*
 These reflect the 24-bit permission values from structsd 110b
 https://github.com/playstructs/structsd/blob/110b/x/structs/types/permissions.go

 Bit 0  (1):       PermPlay
 Bit 1  (2):       PermAdmin
 Bit 2  (4):       PermUpdate
 Bit 3  (8):       PermDelete
 Bit 4  (16):      PermTokenTransfer
 Bit 5  (32):      PermTokenInfuse
 Bit 6  (64):      PermTokenMigrate
 Bit 7  (128):     PermTokenDefuse
 Bit 8  (256):     PermSourceAllocation
 Bit 9  (512):     PermGuildMembership
 Bit 10 (1024):    PermSubstationConnection
 Bit 11 (2048):    PermAllocationConnection
 Bit 12 (4096):    PermGuildTokenBurn
 Bit 13 (8192):    PermGuildTokenMint
 Bit 14 (16384):   PermGuildEndpointUpdate
 Bit 15 (32768):   PermGuildJoinConstraintsUpdate
 Bit 16 (65536):   PermGuildSubstationUpdate
 Bit 17 (131072):  PermProviderWithdraw
 Bit 18 (262144):  PermProviderOpen
 Bit 19 (524288):  PermReactorGuildCreate
 Bit 20 (1048576): PermHashBuild
 Bit 21 (2097152): PermHashMine
 Bit 22 (4194304): PermHashRefine
 Bit 23 (8388608): PermHashRaid
 */

    DROP VIEW IF EXISTS view.permission_address;

    CREATE OR REPLACE VIEW view.permission_address AS
    SELECT
        permission.object_index as address,
        (permission.val & 1) > 0 as perm_play,
        (permission.val & 2) > 0 as perm_admin,
        (permission.val & 4) > 0 as perm_update,
        (permission.val & 8) > 0 as perm_delete,
        (permission.val & 16) > 0 as perm_token_transfer,
        (permission.val & 32) > 0 as perm_token_infuse,
        (permission.val & 64) > 0 as perm_token_migrate,
        (permission.val & 128) > 0 as perm_token_defuse,
        (permission.val & 256) > 0 as perm_source_allocation,
        (permission.val & 512) > 0 as perm_guild_membership,
        (permission.val & 1024) > 0 as perm_substation_connection,
        (permission.val & 2048) > 0 as perm_allocation_connection,
        (permission.val & 4096) > 0 as perm_guild_token_burn,
        (permission.val & 8192) > 0 as perm_guild_token_mint,
        (permission.val & 16384) > 0 as perm_guild_endpoint_update,
        (permission.val & 32768) > 0 as perm_guild_join_constraints_update,
        (permission.val & 65536) > 0 as perm_guild_substation_update,
        (permission.val & 131072) > 0 as perm_provider_withdraw,
        (permission.val & 262144) > 0 as perm_provider_open,
        (permission.val & 524288) > 0 as perm_reactor_guild_create,
        (permission.val & 1048576) > 0 as perm_hash_build,
        (permission.val & 2097152) > 0 as perm_hash_mine,
        (permission.val & 4194304) > 0 as perm_hash_refine,
        (permission.val & 8388608) > 0 as perm_hash_raid,
        permission.updated_at

    FROM structs.permission
    WHERE permission.object_type = 'address';

    DROP VIEW IF EXISTS view.permission_player;

    CREATE OR REPLACE VIEW view.permission_player AS
    SELECT
        permission.object_id as object_id,
        permission.object_type as object_type,
        permission.player_id as player_id,

        (permission.val & 1) > 0 as perm_play,
        (permission.val & 2) > 0 as perm_admin,
        (permission.val & 4) > 0 as perm_update,
        (permission.val & 8) > 0 as perm_delete,
        (permission.val & 16) > 0 as perm_token_transfer,
        (permission.val & 32) > 0 as perm_token_infuse,
        (permission.val & 64) > 0 as perm_token_migrate,
        (permission.val & 128) > 0 as perm_token_defuse,
        (permission.val & 256) > 0 as perm_source_allocation,
        (permission.val & 512) > 0 as perm_guild_membership,
        (permission.val & 1024) > 0 as perm_substation_connection,
        (permission.val & 2048) > 0 as perm_allocation_connection,
        (permission.val & 4096) > 0 as perm_guild_token_burn,
        (permission.val & 8192) > 0 as perm_guild_token_mint,
        (permission.val & 16384) > 0 as perm_guild_endpoint_update,
        (permission.val & 32768) > 0 as perm_guild_join_constraints_update,
        (permission.val & 65536) > 0 as perm_guild_substation_update,
        (permission.val & 131072) > 0 as perm_provider_withdraw,
        (permission.val & 262144) > 0 as perm_provider_open,
        (permission.val & 524288) > 0 as perm_reactor_guild_create,
        (permission.val & 1048576) > 0 as perm_hash_build,
        (permission.val & 2097152) > 0 as perm_hash_mine,
        (permission.val & 4194304) > 0 as perm_hash_refine,
        (permission.val & 8388608) > 0 as perm_hash_raid,
        permission.updated_at

    FROM structs.permission
    WHERE permission.object_type != 'address';

COMMIT;
