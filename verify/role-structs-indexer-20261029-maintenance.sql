-- Verify structs-pg:role-structs-indexer-20261029-maintenance on pg
BEGIN;
DO $$
DECLARE rel TEXT;
BEGIN
    IF NOT has_schema_privilege('structs_indexer','view','USAGE') THEN
        RAISE EXCEPTION 'indexer maintenance needs view schema access';
    END IF;
    FOREACH rel IN ARRAY ARRAY['sync_state.sync_cursor','structs.current_block',
        'structs.ledger','structs.struct','structs.planet','view.work_live'] LOOP
        IF NOT has_table_privilege('structs_indexer',rel,'SELECT') THEN
            RAISE EXCEPTION 'indexer maintenance lacks SELECT on %', rel;
        END IF;
    END LOOP;
END $$;
ROLLBACK;
