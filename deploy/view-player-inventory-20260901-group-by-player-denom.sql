-- Deploy structs-pg:view-player-inventory-20260901-group-by-player-denom to pg
--
-- Roll up player inventory by (player_id, denom) instead of retaining
-- player_address.address in GROUP BY, which could emit duplicate rows for
-- players with balances on more than one approved address.

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
        GROUP BY player_address.player_id, address_inventory.denom;

COMMIT;
