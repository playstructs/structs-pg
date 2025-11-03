-- Deploy structs-pg:view-leaderboard-guild to pg

BEGIN;

    CREATE OR REPLACE VIEW view.leaderboard_guild AS
        select
            guild_meta.id,
            guild_meta.name,
            guild_meta.tag,
            (select count(1) from structs.player where player.guild_id = guild_meta.id) as player_count,
            guild_bank.collateral_balance,
            structs.UNIT_DISPLAY_FORMAT(guild_bank.collateral_balance, 'ualpha') as display_collateral_balance,
            guild_bank.ratio,
            ROUND(guild_bank.ratio * 100, 2) || '%' as display_ratio
        from guild_meta
                 left join view.guild_bank on guild_meta.id = guild_bank.id;

COMMIT;
