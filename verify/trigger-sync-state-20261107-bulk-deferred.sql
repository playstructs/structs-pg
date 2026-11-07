-- Verify structs-pg:trigger-sync-state-20261107-bulk-deferred on pg
BEGIN;
DO $$
DECLARE n integer;
BEGIN
    SELECT count(*) INTO n FROM pg_trigger t
    JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_proc p ON p.oid=t.tgfoid
    WHERE c.relnamespace='structs'::regnamespace AND p.pronamespace='structs'::regnamespace
      AND p.proname IN ('planet_activity_notify','inventory_notify','grid_notify','api_work_mark_dirty')
      AND NOT t.tgisinternal AND t.tgenabled='O'
      AND position('structs.bulk_deferred' in pg_get_triggerdef(t.oid))>0;
    IF n<>21 THEN RAISE EXCEPTION 'expected 21 gated notification/work triggers, found %',n; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='structs.planet_activity'::regclass
        AND tgname='planet_activity_attribute' AND tgenabled='O'
        AND position('structs.bulk_deferred' in pg_get_triggerdef(oid))=0) THEN
        RAISE EXCEPTION 'historical activity attribution must remain unconditional';
    END IF;
END $$;
ROLLBACK;
