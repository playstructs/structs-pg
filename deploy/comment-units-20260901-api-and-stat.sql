-- Deploy structs-pg:comment-units-20260901-api-and-stat to pg
--
-- Document precision units on api_* read-model columns and stat_*.value.
-- Bare api_* column names hold chain precision (not legacy display values).

BEGIN;

    -- api_leaderboard_player
    COMMENT ON COLUMN structs.api_leaderboard_player.alpha_balance IS
        'Chain precision in ualpha (micrograms). Divide by 1_000_000 for legacy gram-scale alpha.';
    COMMENT ON COLUMN structs.api_leaderboard_player.alpha_value IS
        'Chain precision in ualpha (micrograms). Paper value including guild bank exposure.';

    -- api_leaderboard_guild
    COMMENT ON COLUMN structs.api_leaderboard_guild.collateral IS
        'Chain precision in ualpha (micrograms). Guild bank collateral pool balance.';
    COMMENT ON COLUMN structs.api_leaderboard_guild.supply IS
        'Chain precision in uguild base units (micrograms). Minted guild token supply.';
    COMMENT ON COLUMN structs.api_leaderboard_guild.member_capacity IS
        'Chain precision in milliwatts. Sum of member player capacity.';
    COMMENT ON COLUMN structs.api_leaderboard_guild.member_load IS
        'Chain precision in milliwatts. Sum of member player load.';
    COMMENT ON COLUMN structs.api_leaderboard_guild.shared_connection_capacity IS
        'Chain precision in milliwatts. Sum of substation connection capacity.';

    -- api_leaderboard_reactor
    COMMENT ON COLUMN structs.api_leaderboard_reactor.fuel IS
        'Chain precision in ualpha (micrograms). Reactor fuel on hand.';
    COMMENT ON COLUMN structs.api_leaderboard_reactor.power IS
        'Chain precision in milliwatts. Reactor generating capacity.';

    -- api_leaderboard_substation
    COMMENT ON COLUMN structs.api_leaderboard_substation.load IS
        'Chain precision in milliwatts.';
    COMMENT ON COLUMN structs.api_leaderboard_substation.member_capacity IS
        'Chain precision in milliwatts. Sum of connected player capacity.';
    COMMENT ON COLUMN structs.api_leaderboard_substation.shared_connection_capacity IS
        'Chain precision in milliwatts. Substation connection capacity.';

    -- api_leaderboard_provider
    COMMENT ON COLUMN structs.api_leaderboard_provider.rate_amount IS
        'Chain precision in the unit given by rate_denom (ualpha, milliwatt, ore, etc.).';

    -- api_inventory
    COMMENT ON COLUMN structs.api_inventory.balance IS
        'Chain precision in the unit of denom (ualpha micrograms, ore grams, uguild.* micrograms).';

    -- api_guild_bank
    COMMENT ON COLUMN structs.api_guild_bank.collateral IS
        'Chain precision in the unit of denom (ualpha or uguild.* micrograms).';
    COMMENT ON COLUMN structs.api_guild_bank.supply IS
        'Chain precision in the unit of denom (uguild.* micrograms).';

    -- stat_* time series
    COMMENT ON COLUMN structs.stat_load.value IS
        'Chain precision in milliwatts. Same scale as grid.val for attribute load.';
    COMMENT ON COLUMN structs.stat_capacity.value IS
        'Chain precision in milliwatts. Same scale as grid.val for attribute capacity.';
    COMMENT ON COLUMN structs.stat_connection_capacity.value IS
        'Chain precision in milliwatts. Same scale as grid.val for attribute connectionCapacity.';
    COMMENT ON COLUMN structs.stat_structs_load.value IS
        'Chain precision in milliwatts. Same scale as grid.val for attribute structsLoad.';
    COMMENT ON COLUMN structs.stat_power.value IS
        'Chain precision in milliwatts. Same scale as grid.val for attribute power.';
    COMMENT ON COLUMN structs.stat_fuel.value IS
        'Chain precision in ualpha (micrograms). Same scale as grid.val for attribute fuel.';
    COMMENT ON COLUMN structs.stat_ore.value IS
        'Ore in grams (1:1 with grid.val). No legacy divisor.';
    COMMENT ON COLUMN structs.stat_connection_count.value IS
        'Connection count (dimensionless integer stored as numeric).';
    COMMENT ON COLUMN structs.stat_struct_health.value IS
        'Struct health points (dimensionless).';
    COMMENT ON COLUMN structs.stat_struct_status.value IS
        'Struct status code (integer enum value).';

COMMIT;
