-- Verify structs-pg:view-inventory-20260914-read-api-current-state on pg

BEGIN;

    SELECT address, balance, denom FROM view.address_inventory WHERE FALSE;
    SELECT player_id, balance, denom FROM view.player_inventory WHERE FALSE;

    DO $$
    DECLARE
        addr_def text;
        player_def text;
    BEGIN
        SELECT pg_get_viewdef('view.address_inventory'::regclass, true) INTO addr_def;
        SELECT pg_get_viewdef('view.player_inventory'::regclass, true) INTO player_def;

        IF position('api_inventory' in addr_def) = 0 THEN
            RAISE EXCEPTION 'view.address_inventory does not read structs.api_inventory';
        END IF;
        IF position('unit_legacy_format' in lower(addr_def)) = 0 THEN
            RAISE EXCEPTION 'view.address_inventory must convert with UNIT_LEGACY_FORMAT';
        END IF;
        IF position('owner_type' in addr_def) = 0 OR position('''address''' in addr_def) = 0 THEN
            RAISE EXCEPTION 'view.address_inventory must filter owner_type = address';
        END IF;

        IF position('api_inventory' in player_def) = 0 THEN
            RAISE EXCEPTION 'view.player_inventory does not read structs.api_inventory';
        END IF;
        IF position('unit_legacy_format' in lower(player_def)) = 0 THEN
            RAISE EXCEPTION 'view.player_inventory must convert with UNIT_LEGACY_FORMAT';
        END IF;
        IF position('ledger' in player_def) > 0 THEN
            RAISE EXCEPTION 'view.player_inventory should not scan structs.ledger';
        END IF;
    END
    $$;

ROLLBACK;
