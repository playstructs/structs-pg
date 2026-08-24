-- Verify structs-pg:view-work-20260824-planet-ore-clocks on pg

BEGIN;

    SELECT object_id, player_id, target_id, category, block_start, difficulty_target
    FROM view.work
    WHERE FALSE;

    DO $$
    DECLARE
        def text;
    BEGIN
        def := pg_get_viewdef('view.work'::regclass, true);
        IF position('''12-''' in def) = 0 OR position('planet_attribute' in def) = 0 THEN
            RAISE EXCEPTION 'view.work does not look up planet ore mine clock (12-)';
        END IF;
        IF position('''13-''' in def) = 0 THEN
            RAISE EXCEPTION 'view.work does not look up planet ore refine clock (13-)';
        END IF;
        IF position('''3-''' in def) > 0 THEN
            RAISE EXCEPTION 'view.work still looks up struct ore mine clock (3-)';
        END IF;
        IF position('''4-''' in def) > 0 THEN
            RAISE EXCEPTION 'view.work still looks up struct ore refine clock (4-)';
        END IF;
    END $$;

ROLLBACK;
