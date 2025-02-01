-- Deploy structs-pg:view-guild to pg

BEGIN;

CREATE OR REPLACE VIEW view.guild AS
    SELECT
       *

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


    FROM structs.guild;


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


COMMIT;
