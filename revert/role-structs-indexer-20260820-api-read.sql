-- Revert structs-pg:role-structs-indexer-20260820-api-read from pg

BEGIN;

    REVOKE SELECT, INSERT, UPDATE, DELETE
        ON structs.api_refresh_state,
           structs.api_leaderboard_player,
           structs.api_leaderboard_guild,
           structs.api_leaderboard_reactor,
           structs.api_leaderboard_substation,
           structs.api_leaderboard_provider,
           structs.api_inventory,
           structs.api_guild_bank
        FROM structs_indexer;

COMMIT;
