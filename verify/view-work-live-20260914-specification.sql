-- Verify structs-pg:view-work-live-20260914-specification on pg

BEGIN;

    SELECT object_id, player_id, target_id, category, block_start,
           difficulty_target, location_type, location_id, planet_id
      FROM view.work_live WHERE FALSE;

    SELECT object_id, player_id, target_id, category, block_start,
           difficulty_target, location_type, location_id, planet_id
      FROM view.work WHERE FALSE;

    DO $$
    DECLARE
        mismatched text;
    BEGIN
        -- view.work must keep exactly the view.work_live column set and types.
        SELECT string_agg(l.column_name || ' ' || l.data_type, ', ') INTO mismatched
          FROM information_schema.columns l
          FULL OUTER JOIN information_schema.columns w
            ON w.table_schema = 'view' AND w.table_name = 'work'
           AND w.column_name = l.column_name AND w.data_type = l.data_type
         WHERE l.table_schema = 'view' AND l.table_name = 'work_live'
           AND (w.column_name IS NULL);
        IF mismatched IS NOT NULL THEN
            RAISE EXCEPTION 'view.work columns differ from view.work_live: %', mismatched;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pg_depend d
              JOIN pg_rewrite r ON r.oid = d.objid
             WHERE r.ev_class = 'view.work'::regclass
               AND d.refobjid = 'view.work_live'::regclass
        ) THEN
            RAISE EXCEPTION 'view.work does not read from view.work_live';
        END IF;
    END
    $$;

ROLLBACK;
