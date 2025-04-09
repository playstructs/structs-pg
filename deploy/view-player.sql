-- Deploy structs-pg:view-player to pg

BEGIN;

CREATE OR REPLACE VIEW view.player AS
        SELECT
            player.id as player_id,
            player_meta.username,
            player.guild_id,
            player.substation_id,
            player.planet_id,
            player.fleet_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='ore'),0) as ore,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) as load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0)/1000) as load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as structs_load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0)/1000) as structs_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) as capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0)/1000) as capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0) as connection_capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)/1000) as connection_capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as total_load_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0)/1000) as total_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)  as total_capacity_p,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)/1000)  as total_capacity,

            player.primary_address,
            player.created_at,
            player.updated_at
        FROM structs.player LEFT JOIN structs.player_meta ON player.id = player_meta.id;


    CREATE OR REPLACE VIEW view.address_inventory AS
        select
                ledger.address,
                sum(case when ledger.direction='debit' then ledger.amount*-1 ELSE ledger.amount END) as balance,
                CASE denom WHEN 'ore' THEN 'ore' ELSE substring(denom, 2, length(denom)-1) END as denom
        from structs.ledger group by ledger.address, ledger.denom;

    CREATE OR REPLACE VIEW view.player_inventory AS
        select
            player_address.player_id,
            sum(address_inventory.balance) as balance,
            address_inventory.denom
        FROM
            structs.player_address,
            view.address_inventory
        WHERE player_address.address = address_inventory.address
        GROUP BY player_address.player_id, player_address.address, address_inventory.denom;


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
                        AND not action in ('infused','defused')
                      group by player_id, ledger.denom
        ), expanded as (
            SELECT base.player_id,
                   sum(CASE denom WHEN 'ualpha' THEN base.hard_balance ELSE 0 END) as hard_balance,
            sum(CASE denom WHEN 'ualpha' THEN base.hard_balance WHEN 'ore' THEN 0 ELSE (SELECT guild_bank.ratio * base.hard_balance FROM view.guild_bank where guild_bank.denom = base.denom) END) as paper_balance
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






