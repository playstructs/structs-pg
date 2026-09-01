-- Verify structs-pg:view-player-inventory-20260901-group-by-player-denom on pg

BEGIN;

    DO $$
    DECLARE
        viewdef text;
    BEGIN
        SELECT pg_get_viewdef('view.player_inventory'::regclass, true) INTO viewdef;

        IF viewdef ~* 'group by.*player_address\.address' THEN
            RAISE EXCEPTION 'view.player_inventory should not GROUP BY player_address.address';
        END IF;
    END
    $$;

    SELECT player_id, balance, denom FROM view.player_inventory WHERE FALSE;

ROLLBACK;
