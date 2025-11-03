-- Deploy structs-pg:view-guild to pg

BEGIN;

    CREATE OR REPLACE VIEW view.guild AS
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

            -- primary reactor fuel infused
            -- primary reactor power generating capacity
            -- primary reactor power allocated in
            -- primary reactor power allocation out
            -- primary reactor power commission capacity

            -- primary substation
            -- primary substation capacity
            -- primary substation allocation_out_load
            -- primary substation player connection count
            -- primary substation player connection capacity
            -- primary substation player struct load avg


        FROM structs.guild LEFT JOIN structs.guild_meta ON guild.id = guild_meta.id;


    CREATE OR REPLACE VIEW view.guild_inventory AS
    select
        player_address.guild_id,
        sum(address_inventory.balance) as balance,
        address_inventory.denom
    FROM
        structs.player_address,
        view.address_inventory
    WHERE player_address.address = address_inventory.address
    GROUP BY player_address.guild_id, address_inventory.denom;

    CREATE OR REPLACE VIEW view.leaderboard_player AS
    WITH base AS (select player_address.player_id,
                         sum(case
                                 when ledger.direction = 'debit' then ledger.amount_p * -1
                                 ELSE ledger.amount_p END) as hard_balance,
                         denom                             as denom
                  from structs.ledger,
                       structs.player_address
                  WHERE
                          player_address.address = ledger.address
                  group by player_id, ledger.denom
    ), expanded as (
        SELECT base.player_id,
               sum(CASE denom WHEN 'ualpha' THEN base.hard_balance ELSE 0 END) as hard_balance,
               sum(CASE denom WHEN 'ualpha' THEN base.hard_balance WHEN 'ualpha.infused' THEN base.hard_balance WHEN 'ualpha.defusing' THEN base.hard_balance WHEN 'ore' THEN 0 ELSE (SELECT guild_bank.ratio * base.hard_balance FROM view.guild_bank where guild_bank.denom = base.denom) END) as paper_balance
        FROM base GROUP BY base.player_id
    )
    select
        expanded.player_id,
        player_discord.discord_username,
        expanded.hard_balance as alpha_balance,
        structs.UNIT_DISPLAY_FORMAT(expanded.hard_balance, 'ualpha') as display_alpha_balance,
        expanded.paper_balance as alpha_value,
        structs.UNIT_DISPLAY_FORMAT(expanded.paper_balance, 'ualpha') as display_alpha_value
    from
        expanded left join structs.player_discord on player_discord.player_id = expanded.player_id;


COMMIT;
