-- Revert structs-pg:schema-sync-state-20261029-event-phase from pg
BEGIN;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM sync_state.infusion_event_position WHERE phase IS NOT NULL)
       OR EXISTS (SELECT 1 FROM sync_state.economy_event_position) THEN
        RAISE EXCEPTION 'phase-aware positions exist; retain replay guards or restore a verified checkpoint';
    END IF;
END $$;
DROP TABLE sync_state.economy_event_position;
ALTER TABLE sync_state.infusion_event_position DROP COLUMN phase;
-- Retain the old bootstrap table, coordinates and shared schema access.
COMMIT;
