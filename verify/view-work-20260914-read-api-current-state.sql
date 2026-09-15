-- Verify structs-pg:view-work-20260914-read-api-current-state on pg

BEGIN;

    SELECT object_id, player_id, target_id, category, block_start,
           difficulty_target, location_type, location_id, planet_id
      FROM view.work WHERE FALSE;

    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_depend d
              JOIN pg_rewrite r ON r.oid = d.objid
             WHERE r.ev_class = 'view.work'::regclass
               AND d.refobjid = 'structs.api_work'::regclass
        ) THEN
            RAISE EXCEPTION 'view.work does not read from structs.api_work';
        END IF;

        IF EXISTS (
            SELECT 1 FROM pg_depend d
              JOIN pg_rewrite r ON r.oid = d.objid
             WHERE r.ev_class = 'view.work'::regclass
               AND d.refobjid = 'view.work_live'::regclass
        ) THEN
            RAISE EXCEPTION 'view.work still reads from view.work_live';
        END IF;
    END
    $$;

ROLLBACK;
