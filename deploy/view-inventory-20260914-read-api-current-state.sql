-- Deploy structs-pg:view-inventory-20260914-read-api-current-state to pg
--
-- Serve view.address_inventory and view.player_inventory from the indexer
-- current-state tables instead of aggregating structs.ledger on every read.
-- Column names, stripped denoms (alpha / guild.* / ore), and legacy floor
-- balances are unchanged so existing webapp SQL keeps working.

BEGIN;

    CREATE OR REPLACE VIEW view.address_inventory AS
        SELECT
            owner_id AS address,
            structs.UNIT_LEGACY_FORMAT(balance, denom) AS balance,
            CASE denom
                WHEN 'ore' THEN 'ore'
                ELSE substring(denom, 2, length(denom) - 1)
            END AS denom
        FROM structs.api_inventory
        WHERE owner_type = 'address';

    CREATE OR REPLACE VIEW view.player_inventory AS
        SELECT
            owner_id AS player_id,
            structs.UNIT_LEGACY_FORMAT(balance, denom) AS balance,
            CASE denom
                WHEN 'ore' THEN 'ore'
                ELSE substring(denom, 2, length(denom) - 1)
            END AS denom
        FROM structs.api_inventory
        WHERE owner_type = 'player';

COMMIT;
