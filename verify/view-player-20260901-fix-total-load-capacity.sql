-- Verify structs-pg:view-player-20260901-fix-total-load-capacity on pg

BEGIN;

    DO $$
    DECLARE
        viewdef text;
    BEGIN
        SELECT pg_get_viewdef('view.player'::regclass, true) INTO viewdef;

        IF viewdef NOT ILIKE '%unit_legacy_format(%' THEN
            RAISE EXCEPTION 'view.player total_load/total_capacity should use UNIT_LEGACY_FORMAT';
        END IF;
    END
    $$;

    SELECT total_load, total_capacity FROM view.player WHERE FALSE;

ROLLBACK;
