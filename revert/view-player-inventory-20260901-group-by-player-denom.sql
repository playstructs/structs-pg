-- Revert structs-pg:view-player-inventory-20260901-group-by-player-denom from pg

BEGIN;

    CREATE OR REPLACE VIEW view.player_inventory AS
        SELECT
            player_address.player_id,
            sum(address_inventory.balance) AS balance,
            address_inventory.denom
        FROM
            structs.player_address,
            view.address_inventory
        WHERE player_address.address = address_inventory.address
        GROUP BY player_address.player_id, player_address.address, address_inventory.denom;

COMMIT;
