-- Revert structs-pg:trigger-grass-inventory from pg

BEGIN;

DROP TRIGGER IF EXISTS INVENTORY_NOTIFY ON structs.ledger;
DROP FUNCTION IF EXISTS structs.INVENTORY_NOTIFY();

COMMIT;
