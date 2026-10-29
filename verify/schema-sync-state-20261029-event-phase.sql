-- Verify structs-pg:schema-sync-state-20261029-event-phase on pg
BEGIN;
SELECT destination_id,address,height,phase,tx_index,event_index FROM sync_state.infusion_event_position WHERE FALSE;
SELECT family,entity_id,height,phase,tx_index,event_index FROM sync_state.economy_event_position WHERE FALSE;
DO $$
DECLARE rel TEXT; privilege TEXT;
BEGIN
    IF NOT has_schema_privilege('structs_indexer','sync_state','USAGE') THEN
        RAISE EXCEPTION 'indexer cannot access event positions';
    END IF;
    FOREACH rel IN ARRAY ARRAY['infusion_event_position','economy_event_position'] LOOP
        FOREACH privilege IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE'] LOOP
            IF NOT has_table_privilege('structs_indexer','sync_state.' || rel,privilege) THEN
                RAISE EXCEPTION 'missing % on %',privilege,rel;
            END IF;
        END LOOP;
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid='sync_state.infusion_event_position'::regclass
        AND attname='phase' AND atttypid='int2'::regtype AND NOT attnotnull) THEN
        RAISE EXCEPTION 'legacy infusion phase must remain nullable';
    END IF;
END $$;
ROLLBACK;
