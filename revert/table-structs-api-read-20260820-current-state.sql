-- Revert structs-pg:table-structs-api-read-20260820-current-state from pg

BEGIN;

    DROP TABLE IF EXISTS structs.api_guild_bank;
    DROP TABLE IF EXISTS structs.api_inventory;
    DROP TABLE IF EXISTS structs.api_leaderboard_provider;
    DROP TABLE IF EXISTS structs.api_leaderboard_substation;
    DROP TABLE IF EXISTS structs.api_leaderboard_reactor;
    DROP TABLE IF EXISTS structs.api_leaderboard_guild;
    DROP TABLE IF EXISTS structs.api_leaderboard_player;
    DROP TABLE IF EXISTS structs.api_refresh_state;

COMMIT;
