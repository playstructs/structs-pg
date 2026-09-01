-- Revert structs-pg:comment-units-20260901-api-and-stat from pg

BEGIN;

    COMMENT ON COLUMN structs.api_leaderboard_player.alpha_balance IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_player.alpha_value IS NULL;

    COMMENT ON COLUMN structs.api_leaderboard_guild.collateral IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_guild.supply IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_guild.member_capacity IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_guild.member_load IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_guild.shared_connection_capacity IS NULL;

    COMMENT ON COLUMN structs.api_leaderboard_reactor.fuel IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_reactor.power IS NULL;

    COMMENT ON COLUMN structs.api_leaderboard_substation.load IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_substation.member_capacity IS NULL;
    COMMENT ON COLUMN structs.api_leaderboard_substation.shared_connection_capacity IS NULL;

    COMMENT ON COLUMN structs.api_leaderboard_provider.rate_amount IS NULL;

    COMMENT ON COLUMN structs.api_inventory.balance IS NULL;

    COMMENT ON COLUMN structs.api_guild_bank.collateral IS NULL;
    COMMENT ON COLUMN structs.api_guild_bank.supply IS NULL;

    COMMENT ON COLUMN structs.stat_load.value IS NULL;
    COMMENT ON COLUMN structs.stat_capacity.value IS NULL;
    COMMENT ON COLUMN structs.stat_connection_capacity.value IS NULL;
    COMMENT ON COLUMN structs.stat_structs_load.value IS NULL;
    COMMENT ON COLUMN structs.stat_power.value IS NULL;
    COMMENT ON COLUMN structs.stat_fuel.value IS NULL;
    COMMENT ON COLUMN structs.stat_ore.value IS NULL;
    COMMENT ON COLUMN structs.stat_connection_count.value IS NULL;
    COMMENT ON COLUMN structs.stat_struct_health.value IS NULL;
    COMMENT ON COLUMN structs.stat_struct_status.value IS NULL;

COMMIT;
