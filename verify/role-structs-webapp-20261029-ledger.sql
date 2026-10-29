-- Verify structs-pg:role-structs-webapp-20261029-ledger on pg
BEGIN;
DO $$
BEGIN
    IF NOT has_table_privilege('structs_webapp','structs.ledger','SELECT') THEN
        RAISE EXCEPTION 'missing webapp ledger read';
    END IF;
END $$;
ROLLBACK;
