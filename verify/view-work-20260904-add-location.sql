-- Verify structs-pg:view-work-20260904-add-location on pg

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
        IF position('location_type' in def) = 0 THEN
            RAISE EXCEPTION 'view.work missing location_type';
        END IF;
        IF position('location_id' in def) = 0 THEN
            RAISE EXCEPTION 'view.work missing location_id';
        END IF;
        IF position('planet_id' in def) = 0 THEN
            RAISE EXCEPTION 'view.work missing planet_id';
        END IF;
        IF position('''12-''' in def) = 0 OR position('planet_attribute' in def) = 0 THEN
            RAISE EXCEPTION 'view.work does not look up planet ore mine clock (12-)';
        END IF;
        IF position('''13-''' in def) = 0 THEN
            RAISE EXCEPTION 'view.work does not look up planet ore refine clock (13-)';
        END IF;
    END $$;

ROLLBACK;
