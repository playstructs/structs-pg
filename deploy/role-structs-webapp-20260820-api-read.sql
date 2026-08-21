-- Deploy structs-pg:role-structs-webapp-20260820-api-read to pg

BEGIN;

    GRANT SELECT
        ON structs.api_refresh_state,
           structs.api_leaderboard_player,
           structs.api_leaderboard_guild,
           structs.api_leaderboard_reactor,
           structs.api_leaderboard_substation,
           structs.api_leaderboard_provider,
           structs.api_inventory,
           structs.api_guild_bank
        TO structs_webapp;

COMMIT;
