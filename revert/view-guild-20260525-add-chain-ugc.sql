-- Revert structs-pg:view-guild-20260525-add-chain-ugc from pg

BEGIN;

    DROP VIEW IF EXISTS view.leaderboard_guild CASCADE;
    DROP VIEW IF EXISTS view.guild_inventory CASCADE;
    DROP VIEW IF EXISTS view.guild CASCADE;

    CREATE VIEW view.guild AS
        SELECT
           guild.id as guild_id,
           guild.endpoint,
           guild.primary_reactor_id,
           guild.entry_substation_id,
           guild.owner,
           guild.updated_at as onchain_updated_at,
           guild_meta.name,
           guild_meta.denom,
           guild_meta.tag,
           guild_meta.this_infrastructure,
           guild_meta.status,
           guild_meta.updated_at as meta_updated_at
        FROM structs.guild LEFT JOIN structs.guild_meta ON guild.id = guild_meta.id;


    CREATE VIEW view.guild_inventory AS
    select
        player_address.guild_id,
        sum(address_inventory.balance) as balance,
        address_inventory.denom
    FROM
        structs.player_address,
        view.address_inventory
    WHERE player_address.address = address_inventory.address
    GROUP BY player_address.guild_id, address_inventory.denom;


    CREATE VIEW view.leaderboard_guild AS
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
