-- Verify structs-pg:view-work-20260914-filterable-unions on pg

BEGIN;

    SELECT object_id, player_id, target_id, category, block_start,
           difficulty_target, location_type, location_id, planet_id
    FROM view.work
    WHERE FALSE;

    DO $$
    DECLARE
        def text;
    BEGIN
        def := pg_get_viewdef('view.work'::regclass, true);
        IF position('UNION ALL' in def) = 0 THEN
            RAISE EXCEPTION 'view.work should use UNION ALL';
        END IF;
        IF def ~ 'UNION[[:space:]]+SELECT' THEN
            RAISE EXCEPTION 'view.work still has a distinct UNION';
        END IF;
        IF position('location_type' in def) = 0
            OR position('location_id' in def) = 0
            OR position('planet_id' in def) = 0 THEN
            RAISE EXCEPTION 'view.work missing location columns';
        END IF;
        IF position('''12-''' in def) = 0 OR position('''13-''' in def) = 0 THEN
            RAISE EXCEPTION 'view.work does not look up planet ore clocks (12-/13-)';
        END IF;
        IF position('fleet' in def) = 0 THEN
            RAISE EXCEPTION 'view.work RAID should join structs.fleet';
        END IF;
    END $$;

ROLLBACK;
