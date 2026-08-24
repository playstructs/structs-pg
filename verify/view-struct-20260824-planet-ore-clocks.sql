-- Verify structs-pg:view-struct-20260824-planet-ore-clocks on pg

BEGIN;

    SELECT struct_id, location_id, block_start_build, block_start_ore_mine, block_start_ore_refine
    FROM view.struct
    WHERE FALSE;

    DO $$
    DECLARE
        def text;
    BEGIN
        def := pg_get_viewdef('view.struct'::regclass, true);
        IF position('''12-''' in def) = 0 OR position('planet_attribute' in def) = 0 THEN
            RAISE EXCEPTION 'view.struct does not look up planet ore mine clock (12-)';
        END IF;
        IF position('''13-''' in def) = 0 THEN
            RAISE EXCEPTION 'view.struct does not look up planet ore refine clock (13-)';
        END IF;
    END $$;

ROLLBACK;
