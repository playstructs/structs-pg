-- Deploy structs-pg:view-player to pg

BEGIN;

CREATE OR REPLACE VIEW view.player AS
        SELECT
            id as player_id,
            guild_id,
            substation_id,
            planet_id,
            fleet_id,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='ore'),0) as ore,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) as load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as structs_load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) as capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0) as connection_capacity,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='load'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='structsLoad'),0) as total_load,
            COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.id and grid.attribute_type='capacity'),0) + COALESCE((SELECT grid.val FROM structs.grid WHERE grid.object_id=player.substation_id and grid.attribute_type='connectionCapacity'),0)  as total_capacity,
            primary_address,
            created_at,
            updated_at
        FROM structs.player;


    CREATE OR REPLACE VIEW view.address_inventory AS
        select ledger.address, sum(case when ledger.direction='debit' then ledger.amount*-1 ELSE ledger.amount END) as balance from structs.ledger group by ledger.address;

    CREATE OR REPLACE VIEW view.player_inventory AS
        select
            player_address.player_id,
            sum(address_inventory.balance) as balance
        FROM
            structs.player_address,
            view.address_inventory
        WHERE player_address.address = address_inventory.address
        GROUP BY player_address.player_id, player_address.address;

COMMIT;
