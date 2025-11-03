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


COMMIT;
