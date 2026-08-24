-- Verify structs-pg:view-planet-20260824-ore-clocks on pg

BEGIN;

    SELECT
        planet_id,
        name,
        block_start_raid,
        block_raider_arrived,
        block_start_ore_mine,
        block_start_ore_refine,
        ore_mining_active_quantity,
        ore_refining_active_quantity
    FROM view.planet
    WHERE FALSE;

    DO $$
    DECLARE
        def text;
    BEGIN
        def := pg_get_viewdef('view.planet'::regclass, true);
        IF position('''12-''' in def) = 0 OR position('''13-''' in def) = 0 THEN
            RAISE EXCEPTION 'view.planet does not look up planet ore clocks (12-/13-)';
        END IF;
        IF position('''11-''' in def) = 0 OR position('''14-''' in def) = 0 OR position('''15-''' in def) = 0 THEN
            RAISE EXCEPTION 'view.planet does not look up planet attrs 11/14/15';
        END IF;
    END $$;

ROLLBACK;
