-- Deploy structs-pg:view-grid to pg

BEGIN;

    CREATE OR REPLACE VIEW view.grid AS
        SELECT
            grid.*
        FROM structs.grid;

    CREATE OR REPLACE VIEW view.leaderboard_provider AS
        select
            id,
            owner,
            (select player_discord.discord_username from structs.player_discord where player_discord.player_id = provider.owner) as discord_username,
            rate_amount,
            rate_denom,
            structs.UNIT_DISPLAY_FORMAT(rate_amount, rate_denom) as display_rate,
            access_policy,
            provider_cancellation_penalty,
            round((provider_cancellation_penalty * 100),4)|| '%' as  display_provider_cancellation_pentalty,
            consumer_cancellation_penalty,
            round((consumer_cancellation_penalty * 100),4)|| '%' as  display_consumer_cancellation_pentalty,
            (select count(1) from structs.agreement where agreement.provider_id = provider.id) as player_count
        from structs.provider;

COMMIT;
