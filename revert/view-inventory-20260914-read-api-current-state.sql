-- Revert structs-pg:view-inventory-20260914-read-api-current-state from pg
--
-- Restores ledger aggregation from view-player-20260525-inline-ugc and
-- view-player-inventory-20260901-group-by-player-denom.

BEGIN;

    CREATE OR REPLACE VIEW view.address_inventory AS
        SELECT
            ledger.address,
            sum(CASE WHEN ledger.direction = 'debit' THEN ledger.amount * -1 ELSE ledger.amount END) AS balance,
            CASE denom WHEN 'ore' THEN 'ore' ELSE substring(denom, 2, length(denom) - 1) END AS denom
        FROM structs.ledger
        GROUP BY ledger.address, ledger.denom;

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
