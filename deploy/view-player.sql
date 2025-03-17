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

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) as load_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0)/1000) as load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as structs_load_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0)/1000) as structs_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) as capacity_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0)/1000) as capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0) as connection_capacity_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)/1000) as connection_capacity,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as total_load_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0)/1000) as total_load,

            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)  as total_capacity_milliwatt,
            floor(COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)/1000)  as total_capacity,

            player.primary_address,
            player.created_at,
            player.updated_at
        FROM structs.player, structs.player_meta
            WHERE player.id = player_meta.id;


    CREATE OR REPLACE VIEW view.address_inventory AS
        select
                ledger.address,
                sum(case when ledger.direction='debit' then ledger.amount*-1 ELSE ledger.amount END) as balance,
                denom
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

COMMIT;
